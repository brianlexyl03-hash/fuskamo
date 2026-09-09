const { getSupabaseAdmin } = require('../config/supabase');
const AppError = require('../errors/AppError');
const logger = require('../utils/logger');

/**
 * Super-Admin-only management of other administrator accounts. Every
 * mutating method here requires the caller to already have passed
 * adminAuth + requireRole('Super Admin') at the route level — this class
 * does not re-check that, by design (single responsibility; the route is
 * the enforcement point, see docs/admin-access.md).
 *
 * Account creation uses Supabase Auth's own invite flow
 * (auth.admin.inviteUserByEmail) rather than setting a password ourselves —
 * the invited admin sets their own password via the email link Supabase
 * sends, so no admin password ever passes through our backend or logs,
 * even transiently.
 */
class AdminAccountsRepository {
  _client() {
    const client = getSupabaseAdmin();
    if (!client) throw new AppError('Supabase is not configured on this server yet', 503);
    return client;
  }

  async listRoles() {
    const { data, error } = await this._client().from('admin_roles').select('id, name, description').order('name');
    if (error) throw new AppError(error.message, 400);
    return data;
  }

  async list() {
    const { data, error } = await this._client()
      .from('admin_users')
      .select('id, email, display_name, status, mfa_enabled, last_login_at, created_at, admin_roles(id, name)')
      .order('created_at', { ascending: false });
    if (error) throw new AppError(error.message, 400);
    return data.map((a) => ({ ...a, role: a.admin_roles?.name, roleId: a.admin_roles?.id, admin_roles: undefined }));
  }

  /** Invites a brand-new administrator: creates the Supabase Auth user
   * (unconfirmed, no password set by us) via an email invite, then creates
   * the matching admin_users row with the chosen role. If the admin_users
   * insert fails after the auth user was created, the auth user is rolled
   * back so we never end up with an orphaned login that has no role. */
  async invite({ email, displayName, roleId, redirectTo, createdBy }) {
    const client = this._client();

    const { data: roleRow, error: roleErr } = await client.from('admin_roles').select('id').eq('id', roleId).maybeSingle();
    if (roleErr) throw new AppError(roleErr.message, 400);
    if (!roleRow) throw new AppError('Unknown role', 400);

    const { data: invited, error: inviteErr } = await client.auth.admin.inviteUserByEmail(email, {
      redirectTo,
      data: { display_name: displayName || '' },
    });
    if (inviteErr) throw new AppError(inviteErr.message, 400);

    const { data: adminRow, error: insertErr } = await client
      .from('admin_users')
      .insert([
        {
          id: invited.user.id,
          email,
          display_name: displayName || '',
          role_id: roleId,
          status: 'active',
          created_by: createdBy,
        },
      ])
      .select('id, email, display_name, status, admin_roles(id, name)')
      .single();

    if (insertErr) {
      // Roll back the auth user so we don't leave a login with no admin role.
      await client.auth.admin.deleteUser(invited.user.id).catch((e) =>
        logger.error(`Failed to roll back orphaned auth user ${invited.user.id} after admin_users insert failure`, e)
      );
      throw new AppError(insertErr.message, 400);
    }

    return adminRow;
  }

  async updateRole(adminId, roleId) {
    const { data, error } = await this._client()
      .from('admin_users')
      .update({ role_id: roleId, updated_at: new Date().toISOString() })
      .eq('id', adminId)
      .select('id, email, admin_roles(id, name)')
      .single();
    if (error) throw new AppError(error.message, 400);
    return data;
  }

  async setStatus(adminId, status) {
    const { data, error } = await this._client()
      .from('admin_users')
      .update({ status, updated_at: new Date().toISOString() })
      .eq('id', adminId)
      .select('id, email, status')
      .single();
    if (error) throw new AppError(error.message, 400);
    return data;
  }

  /** Disable: reversible, blocks login immediately (adminAuth checks
   * status === 'active'). Existing sessions still get rejected on their
   * next request since every request re-checks status — no separate
   * session revocation needed, but we do it anyway for immediate effect
   * on long-lived tokens rather than waiting for a natural re-check. */
  async disable(adminId) {
    await this.revokeSessions(adminId);
    return this.setStatus(adminId, 'disabled');
  }

  /** Suspend: same mechanics as disable, distinct status so a Super Admin
   * can tell "temporarily paused" (suspended) from "administratively
   * turned off" (disabled) at a glance — both block login identically. */
  async suspend(adminId) {
    await this.revokeSessions(adminId);
    return this.setStatus(adminId, 'suspended');
  }

  async reactivate(adminId) {
    return this.setStatus(adminId, 'active');
  }

  /** Revoke: permanent. Unlike disable/suspend, this also deletes the
   * underlying Supabase Auth user entirely — there is no "reactivate" path
   * back from here, matching the "permanently revoke" requirement. The
   * admin_users row is kept (status='revoked') rather than deleted, so the
   * audit log's admin_id foreign key and history stay intact. */
  async revoke(adminId) {
    const client = this._client();
    await this.revokeSessions(adminId);
    await this.setStatus(adminId, 'revoked');
    const { error } = await client.auth.admin.deleteUser(adminId);
    if (error) {
      // The admin is already locked out via status='revoked' (checked on
      // every request) even if the auth-layer delete fails — log loudly
      // rather than throwing, since the account is already inaccessible.
      logger.error(`Revoked admin ${adminId} but failed to delete underlying auth user`, error);
    }
    return { id: adminId, status: 'revoked' };
  }

  /** Used by disable/suspend/revoke above, and exposed separately for
   * "log me out everywhere" self-service (see adminAuthRepository). Calls
   * Supabase's own global sign-out (invalidates every refresh token for
   * this user at the Auth layer) and marks our own admin_sessions rows
   * revoked so both layers agree. */
  async revokeSessions(adminId) {
    const client = this._client();
    const { error } = await client.auth.admin.signOut(adminId, 'global');
    if (error) logger.warn(`auth.admin.signOut failed for ${adminId}: ${error.message}`);
    const { error: sessErr } = await client
      .from('admin_sessions')
      .update({ revoked_at: new Date().toISOString() })
      .eq('admin_id', adminId)
      .is('revoked_at', null);
    if (sessErr) logger.warn(`Could not mark admin_sessions revoked for ${adminId}: ${sessErr.message}`);
  }
}

module.exports = new AdminAccountsRepository();
