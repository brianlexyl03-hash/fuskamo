const env = require('../config/env');
const AppError = require('../errors/AppError');
const { getSupabaseAdmin } = require('../config/supabase');
const { auditLog } = require('../utils/auditLogger');
const logger = require('../utils/logger');
const { verifySupabaseJwt } = require('./verifySupabaseJwt');

/**
 * Replaces the old shared ADMIN_API_KEY entirely. Every administrator signs
 * in with their own Supabase Auth account (email/password, optionally
 * TOTP MFA — both handled by Supabase Auth itself, not custom code here —
 * see docs/admin-access.md for why). This middleware:
 *
 *  1. Verifies the bearer token is a real, unexpired Supabase session JWT.
 *  2. Loads the matching admin_users row (does the auth.users id even have
 *     an admin account?) plus its role and permission set.
 *  3. Enforces account status (active / disabled / suspended / revoked)
 *     and any lockout window from repeated failures.
 *  4. If that admin has MFA enabled, requires the token's `aal` (Authenticator
 *     Assurance Level) claim to be 'aal2' — proof a second factor was
 *     actually verified by Supabase's own servers. We never trust a client
 *     claim of "MFA passed"; aal2 can only appear in a JWT Supabase itself
 *     issued after a successful TOTP challenge.
 *  5. Attaches req.adminUser (id, email, role, permissions) and
 *     req.adminContext (ip, userAgent, sessionId) for controllers/audit.
 *  6. Upserts an admin_sessions row so "logout everywhere" / per-session
 *     revocation has something real to act on.
 *
 * Every admin route must use this. There is no other way into anything
 * under /api/admin*, /api/players-admin*, /api/scouts-admin*.
 */
module.exports = async function adminAuth(req, res, next) {
  try {
    const header = req.header('authorization') || '';
    const token = header.startsWith('Bearer ') ? header.slice(7) : null;
    if (!token) return next(new AppError('Missing bearer token', 401));

    if (!env.supabase.jwtSecret) {
      return next(new AppError('Admin auth is not configured on this server (SUPABASE_JWT_SECRET unset)', 503));
    }

    let decoded;
    try {
      decoded = await verifySupabaseJwt(token);
    } catch (e) {
      return next(new AppError('Invalid or expired session', 401));
    }

    const client = getSupabaseAdmin();
    if (!client) return next(new AppError('Admin auth is not configured on this server (Supabase unset)', 503));

    const { data: admin, error } = await client
      .from('admin_users')
      .select('id, email, display_name, status, mfa_enabled, locked_until, admin_roles(id, name)')
      .eq('id', decoded.sub)
      .maybeSingle();

    if (error) {
      logger.error('adminAuth: failed to load admin_users row', error);
      return next(new AppError('Could not verify admin account', 500));
    }
    if (!admin) return next(new AppError('This account has no admin access', 403));

    if (admin.status !== 'active') {
      return next(new AppError(`Admin account is ${admin.status}`, 403));
    }
    if (admin.locked_until && new Date(admin.locked_until) > new Date()) {
      return next(new AppError('Admin account is temporarily locked — try again later', 423));
    }

    if (admin.mfa_enabled && decoded.aal !== 'aal2') {
      return next(new AppError('This account requires MFA verification for admin access', 401));
    }
    req.aal = decoded.aal || 'aal1';

    const { data: permRows, error: permError } = await client
      .from('admin_role_permissions')
      .select('admin_permissions(resource, action)')
      .eq('role_id', admin.admin_roles.id);

    if (permError) {
      logger.error('adminAuth: failed to load permissions', permError);
      return next(new AppError('Could not verify admin permissions', 500));
    }
    const permissions = new Set(
      (permRows || []).map((r) => `${r.admin_permissions.resource}:${r.admin_permissions.action}`)
    );

    req.adminUser = {
      id: admin.id,
      email: admin.email,
      displayName: admin.display_name,
      role: admin.admin_roles.name,
      roleId: admin.admin_roles.id,
      permissions,
      mfaEnabled: admin.mfa_enabled,
    };
    req.adminContext = {
      ip: req.ip,
      userAgent: req.header('user-agent') || '',
      sessionId: decoded.session_id || decoded.sid || null,
    };
    // Kept for any code that still reads req.adminActor (audit trail label).
    req.adminActor = admin.email;

    // Best-effort session bookkeeping — never blocks the request.
    if (req.adminContext.sessionId) {
      client
        .from('admin_sessions')
        .upsert(
          {
            admin_id: admin.id,
            session_id: req.adminContext.sessionId,
            ip_address: req.adminContext.ip,
            user_agent: req.adminContext.userAgent,
            last_seen_at: new Date().toISOString(),
            expires_at: decoded.exp ? new Date(decoded.exp * 1000).toISOString() : null,
          },
          { onConflict: 'session_id' }
        )
        .then(({ error: sessErr }) => {
          if (sessErr) logger.warn(`Could not upsert admin_sessions row: ${sessErr.message}`);
        });
    }

    next();
  } catch (e) {
    logger.error('adminAuth: unexpected failure', e);
    next(new AppError('Admin authentication failed', 500));
  }
};
