const { getSupabaseAdmin } = require('../config/supabase');
const AppError = require('../errors/AppError');
const notificationRepository = require('./notificationRepository');
const { auditLog } = require('../utils/auditLogger');
const logger = require('../utils/logger');

/** Mirrors playerAdminRepository.js — same reasoning: only the service-role
 * client can flip `verified`, which is what makes a scout visible/listed. */
class ScoutAdminRepository {
  _client() {
    const client = getSupabaseAdmin();
    if (!client) throw new AppError('Supabase is not configured on this server yet', 503);
    return client;
  }

  async _notifyOwner(scout, { title, body, type }) {
    if (!scout.user_id) return;
    try {
      await notificationRepository.create({ userId: scout.user_id, title, body, type });
    } catch (e) {
      logger.warn(`Could not notify scout owner ${scout.user_id}: ${e.message}`);
    }
  }

  /** `adminContext` is { id, email, ip, userAgent, sessionId } built by
   * authentication/adminAuth.js — same pattern as playerAdminRepository.js. */
  async _audit({ adminContext, action, targetId, metadata }) {
    try {
      await auditLog({
        actor: adminContext?.email || 'unknown-admin',
        adminId: adminContext?.id || null,
        ip: adminContext?.ip,
        userAgent: adminContext?.userAgent,
        sessionId: adminContext?.sessionId,
        action,
        targetType: 'scout',
        targetId,
        metadata,
      });
    } catch (e) {
      logger.warn(`Audit log failed for ${action} on scout ${targetId}: ${e.message}`);
    }
  }

  async listPending() {
    const { data, error } = await this._client()
      .from('scouts')
      .select()
      .eq('verified', false)
      .order('created_at', { ascending: true });
    if (error) throw new AppError(error.message, 400);
    return data;
  }

  async approve(scoutId, adminContext) {
    const { data, error } = await this._client()
      .from('scouts')
      .update({ verified: true })
      .eq('id', scoutId)
      .select()
      .single();
    if (error) throw new AppError(error.message, 400);
    await this._audit({ adminContext, action: 'scout.approve', targetId: scoutId, metadata: { name: data.name } });
    await this._notifyOwner(data, {
      title: 'Your scout application was approved',
      body: 'You are now listed as a verified scout on FUSKAMO.',
      type: 'scout_approved',
    });
    return data;
  }

  /** Applications don't have a rejected state to preserve — since scouts
   * has no status column, a reject just removes the pending row rather
   * than leaving it stuck unverified forever with no way to reapply. */
  async reject(scoutId, adminContext) {
    const { data: existing } = await this._client().from('scouts').select().eq('id', scoutId).single();
    const { error } = await this._client().from('scouts').delete().eq('id', scoutId);
    if (error) throw new AppError(error.message, 400);
    await this._audit({
      adminContext,
      action: 'scout.reject',
      targetId: scoutId,
      metadata: { name: existing?.name },
    });
    if (existing) {
      await this._notifyOwner(existing, {
        title: 'Your scout application was not approved',
        body: 'Your application did not meet review criteria this time.',
        type: 'scout_rejected',
      });
    }
    return { id: scoutId };
  }
}

module.exports = new ScoutAdminRepository();
