const { getSupabaseAdmin } = require('../config/supabase');
const AppError = require('../errors/AppError');
const notificationRepository = require('./notificationRepository');
const smsService = require('../notifications/smsService');
const emailService = require('../email/emailService');
const { auditLog } = require('../utils/auditLogger');
const logger = require('../utils/logger');

/**
 * Privileged player operations — uses the Supabase service-role client
 * (config/supabase.js), which bypasses Row Level Security. This is exactly
 * why these operations live in the backend and not the Flutter app: the
 * anon key the app uses can only ever insert a 'pending' row, never
 * approve/reject one.
 */
class PlayerAdminRepository {
  _client() {
    const client = getSupabaseAdmin();
    if (!client) throw new AppError('Supabase is not configured on this server yet', 503);
    return client;
  }

  /** Best-effort — a submission made before submitted_by existed, or one
   * from someone who wasn't signed in, has no user to notify. Never lets a
   * notification failure block the actual approve/reject. */
  async _notifyOwner(player, { title, body, type }) {
    if (!player.submitted_by) return;
    try {
      await notificationRepository.create({ userId: player.submitted_by, title, body, type });
    } catch (e) {
      logger.warn(`Could not notify player owner ${player.submitted_by}: ${e.message}`);
    }
    await this._notifyContact(player, { title, body });
  }

  /** SMS/email are opt-in per the user's notification_preferences and only
   * fire if a contact_email/contact_phone was captured on the submission
   * (see migration 009). Each channel fails independently and silently
   * (missing Africa's Talking or SMTP env vars is expected on a dev box) —
   * a notification failure must never surface to the admin approving/
   * rejecting a player. */
  async _notifyContact(player, { title, body }) {
    let prefs;
    try {
      prefs = await notificationRepository.getPreferences(player.submitted_by);
    } catch (e) {
      logger.warn(`Could not load notification prefs for ${player.submitted_by}: ${e.message}`);
      return;
    }

    if (prefs.sms_enabled && player.contact_phone) {
      try {
        await smsService.send(player.contact_phone, `${title}: ${body}`);
      } catch (e) {
        logger.warn(`SMS notify failed for player ${player.id}: ${e.message}`);
      }
    }

    if (prefs.email_enabled && player.contact_email) {
      try {
        await emailService.send({ to: player.contact_email, subject: title, body });
      } catch (e) {
        logger.warn(`Email notify failed for player ${player.id}: ${e.message}`);
      }
    }
  }

  /** Best-effort, same reasoning as _notifyOwner — an audit-log failure
   * should never block the actual approve/reject from completing.
   * `adminContext` is { id, email, ip, userAgent, sessionId } built by
   * authentication/adminAuth.js, or null for system callers (e.g. the
   * M-Pesa webhook) which pass a plain string actor instead. */
  async _audit({ adminContext, actor, action, targetId, metadata }) {
    try {
      await auditLog({
        actor: adminContext?.email || actor || 'unknown-admin',
        adminId: adminContext?.id || null,
        ip: adminContext?.ip,
        userAgent: adminContext?.userAgent,
        sessionId: adminContext?.sessionId,
        action,
        targetType: 'player',
        targetId,
        metadata,
      });
    } catch (e) {
      logger.warn(`Audit log failed for ${action} on player ${targetId}: ${e.message}`);
    }
  }

  async approve(playerId, adminContext) {
    const { data, error } = await this._client()
      .from('players')
      .update({ status: 'approved' })
      .eq('id', playerId)
      .select()
      .single();
    if (error) throw new AppError(error.message, 400);
    await this._audit({ adminContext, action: 'player.approve', targetId: playerId, metadata: { name: data.name } });
    await this._notifyOwner(data, {
      title: 'Your submission was approved',
      body: `${data.name} is now visible in the FUSKAMO feed.`,
      type: 'player_approved',
    });
    return data;
  }

  async reject(playerId, adminContext) {
    const { data, error } = await this._client()
      .from('players')
      .update({ status: 'rejected' })
      .eq('id', playerId)
      .select()
      .single();
    if (error) throw new AppError(error.message, 400);
    await this._audit({ adminContext, action: 'player.reject', targetId: playerId, metadata: { name: data.name } });
    await this._notifyOwner(data, {
      title: 'Your submission was not approved',
      body: `${data.name}'s submission didn't meet review criteria this time.`,
      type: 'player_rejected',
    });
    return data;
  }

  /** Called by mpesaController.handleCallback once a boost payment
   * completes — see routes/mpesa.routes.js. Only ever reached with a
   * service-role client, same reasoning as approve/reject above: the
   * Flutter app's anon key cannot write to `players` past its initial
   * pending insert. actor is 'mpesa-webhook' here, not a human admin. */
  async featureUntil(playerId, until) {
    const { data, error } = await this._client()
      .from('players')
      .update({ featured_until: until })
      .eq('id', playerId)
      .select()
      .single();
    if (error) throw new AppError(error.message, 400);
    await this._audit({
      actor: 'mpesa-webhook',
      action: 'player.feature',
      targetId: playerId,
      metadata: { name: data.name, until },
    });
    // Duration text is computed from the actual `until` timestamp rather
    // than a second hardcoded "48 hours" — that number previously lived
    // twice (mpesaController.js's BOOST_HOURS and a literal string here),
    // which would silently go stale if BOOST_HOURS ever changed without
    // this string being updated to match.
    const hoursRemaining = Math.round((new Date(until).getTime() - Date.now()) / (60 * 60 * 1000));
    await this._notifyOwner(data, {
      title: 'Your submission is now featured',
      body: `${data.name} will appear at the top of the feed for the next ${hoursRemaining} hours.`,
      type: 'player_featured',
    });
    return data;
  }

  async listPending() {
    const { data, error } = await this._client()
      .from('players')
      .select()
      .eq('status', 'pending')
      .order('created_at', { ascending: true });
    if (error) throw new AppError(error.message, 400);
    return data;
  }
}

module.exports = new PlayerAdminRepository();
