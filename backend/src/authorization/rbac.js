const AppError = require('../errors/AppError');

/**
 * Coarse role check — kept for the handful of places a whole role (not a
 * single permission) is the right boundary, e.g. "only Super Admin can
 * reach the admin-account-management endpoints at all." Most routes should
 * use authorization/permissions.js's requirePermission() instead, which is
 * the actual least-privilege mechanism; this is a defense-in-depth layer
 * on top, not a substitute.
 *
 * Reads req.adminUser.role, set by authentication/adminAuth.js after a
 * real Supabase-verified admin session. There is no client-supplied
 * fallback — a request with no verified admin session has no role at all.
 */
function requireRole(...allowedRoles) {
  return (req, res, next) => {
    const role = req.adminUser?.role;
    if (!role) return next(new AppError('No admin role present on request', 403));
    if (!allowedRoles.includes(role)) {
      return next(new AppError(`Requires one of roles: ${allowedRoles.join(', ')}`, 403));
    }
    next();
  };
}

module.exports = { requireRole };
