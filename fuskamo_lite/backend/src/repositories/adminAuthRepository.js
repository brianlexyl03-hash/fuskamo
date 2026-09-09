const { getSupabaseAdmin } = require('../config/supabase');
const AppError = require('../errors/AppError');
const logger = require('../utils/logger');

/**
 * Self-service operations for the signed-in admin themselves — as opposed
 * to adminAccountsRepository.js, which is Super-Admin-acting-on-others.
 */
class AdminAuthRepository {
  _client() {
    const client = getSupabaseAdmin();
    if (!client) throw new AppError('Supabase is not configured on this server yet', 503);
    return client;
  }

  /** Flips admin_users.mfa_enabled on. Only called after the caller's own
   * JWT already proves aal2 (see controllers/adminAuthController.js) — we
   * never take a client's word for "I set up MFA," only Supabase's own
   * signed claim that a TOTP challenge actually succeeded. */
  async confirmMfaEnabled(adminId) {
    const { data, error } = await this._client()
      .from('admin_users')
      .update({ mfa_enabled: true, updated_at: new Date().toISOString() })
      .eq('id', adminId)
      .select('id, mfa_enabled')
      .single();
    if (error) throw new AppError(error.message, 400);
    return data;
  }

  /** Lets an admin turn MFA back off for their own account (e.g. lost
   * device, re-enrolling). Still requires aal2 on the request that calls
   * this, same as enabling — see controller. */
  async disableMfa(adminId) {
    const { data, error } = await this._client()
      .from('admin_users')
      .update({ mfa_enabled: false, updated_at: new Date().toISOString() })
      .eq('id', adminId)
      .select('id, mfa_enabled')
      .single();
    if (error) throw new AppError(error.message, 400);
    return data;
  }

  async recordLogin(adminId) {
    const { error } = await this._client()
      .from('admin_users')
      .update({ last_login_at: new Date().toISOString(), failed_login_count: 0 })
      .eq('id', adminId);
    if (error) logger.warn(`Could not record login for admin ${adminId}: ${error.message}`);
  }

  async listMySessions(adminId) {
    const { data, error } = await this._client()
      .from('admin_sessions')
      .select('id, session_id, ip_address, user_agent, created_at, last_seen_at, revoked_at, expires_at')
      .eq('admin_id', adminId)
      .is('revoked_at', null)
      .order('last_seen_at', { ascending: false });
    if (error) throw new AppError(error.message, 400);
    return data;
  }

  /** Revoke one session by its admin_sessions row id. Note this cannot
   * revoke the single underlying Supabase refresh token in isolation
   * (Supabase's admin API only supports revoking ALL of a user's sessions
   * at once, not one-by-one) — so a single-session revoke here marks our
   * own row revoked (adminAuth will stop trusting that session_id on its
   * next check) but the other rows are unaffected. For a hard guarantee
   * across every session immediately, use revokeAllSessions instead. */
  async revokeSession(adminId, sessionRowId) {
    const { data, error } = await this._client()
      .from('admin_sessions')
      .update({ revoked_at: new Date().toISOString() })
      .eq('id', sessionRowId)
      .eq('admin_id', adminId) // can only revoke your own sessions this way
      .select('id')
      .maybeSingle();
    if (error) throw new AppError(error.message, 400);
    if (!data) throw new AppError('Session not found', 404);
    return data;
  }

  async revokeAllSessions(adminId) {
    const client = this._client();
    const { error } = await client.auth.admin.signOut(adminId, 'global');
    if (error) throw new AppError(error.message, 400);
    const { error: sessErr } = await client
      .from('admin_sessions')
      .update({ revoked_at: new Date().toISOString() })
      .eq('admin_id', adminId)
      .is('revoked_at', null);
    if (sessErr) logger.warn(`Could not mark admin_sessions revoked for ${adminId}: ${sessErr.message}`);
  }
}

module.exports = new AdminAuthRepository();
