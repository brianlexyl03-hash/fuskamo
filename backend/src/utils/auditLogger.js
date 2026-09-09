const { getSupabaseAdmin } = require('../config/supabase');
const logger = require('./logger');

/**
 * Records who-did-what-when for every privileged action. Writes to
 * `audit_logs` (database/migrations/003_audit_logs.sql, expanded by
 * 013_admin_rbac.sql with admin_id/ip_address/user_agent/session_id).
 *
 * Call with the full adminContext object built by authentication/adminAuth.js
 * wherever possible (req.adminUser + req.adminContext) so every admin
 * action carries a real foreign key to admin_users, not just a free-text
 * label. `actor` stays a plain string for the handful of non-admin callers
 * (system/background jobs) and for human-readable display.
 */
async function auditLog({ actor, adminId, action, targetType, targetId, ip, userAgent, sessionId, metadata = {} }) {
  logger.info(`AUDIT ${actor || adminId || 'system'} ${action} ${targetType}:${targetId}`);
  const client = getSupabaseAdmin();
  if (!client) return; // still logged to stdout above even if DB isn't configured
  const { error } = await client.from('audit_logs').insert([
    {
      actor: actor || 'system',
      admin_id: adminId || null,
      action,
      target_type: targetType,
      target_id: targetId,
      ip_address: ip || null,
      user_agent: userAgent || null,
      session_id: sessionId || null,
      metadata,
    },
  ]);
  if (error) logger.error('Failed to write audit log row', error);
}

/** Convenience wrapper — pass (req, action, targetType, targetId, metadata)
 * from any route that already ran through authentication/adminAuth.js, so
 * callers don't have to manually pull req.adminUser/req.adminContext apart
 * every time. */
async function auditAdminAction(req, action, targetType, targetId, metadata = {}) {
  return auditLog({
    actor: req.adminUser?.email,
    adminId: req.adminUser?.id,
    action,
    targetType,
    targetId,
    ip: req.adminContext?.ip,
    userAgent: req.adminContext?.userAgent,
    sessionId: req.adminContext?.sessionId,
    metadata,
  });
}

module.exports = { auditLog, auditAdminAction };
