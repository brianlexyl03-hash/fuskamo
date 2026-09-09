const AppError = require('../errors/AppError');

/**
 * Granular RBAC check — every admin route declares exactly which
 * resource:action it needs, and req.adminUser.permissions (built by
 * authentication/adminAuth.js from that admin's role) must contain it.
 *
 * Usage: router.post('/:id/approve', adminAuth, requirePermission('players', 'approve'), ...)
 *
 * This is the principle of least privilege in practice: a Support admin's
 * role simply never gets the 'players:approve' permission row, so no code
 * path — however it's reached — can let them approve a player. There is no
 * "requires one of these broad roles" fallback; every privileged action
 * names its own permission.
 */
function requirePermission(resource, action) {
  const needed = `${resource}:${action}`;
  return (req, res, next) => {
    if (!req.adminUser) return next(new AppError('Admin authentication required', 401));
    if (!req.adminUser.permissions.has(needed)) {
      return next(new AppError(`Missing permission: ${needed}`, 403));
    }
    next();
  };
}

module.exports = { requirePermission };
