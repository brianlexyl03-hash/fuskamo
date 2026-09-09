const express = require('express');
const router = express.Router();
const adminAccountsController = require('../controllers/adminAccountsController');
const adminAuth = require('../authentication/adminAuth');
const { requirePermission } = require('../authorization/permissions');
const { adminAccountLimiter } = require('../middleware/adminRateLimiter');

// Everything here needs admins:view or admins:manage — by seed data
// (013_admin_rbac.sql) only the Super Admin role has either, so this
// entire surface is Super-Admin-only in practice, enforced by permission
// rather than a hardcoded role name (a future custom role could be granted
// just admins:view for a read-only ops-audit role without touching code).
router.get('/roles', adminAuth, requirePermission('admins', 'view'), adminAccountsController.listRoles);
router.get('/', adminAuth, requirePermission('admins', 'view'), adminAccountsController.list);
router.post('/invite', adminAuth, requirePermission('admins', 'manage'), adminAccountLimiter, adminAccountsController.invite);
router.patch('/:id/role', adminAuth, requirePermission('admins', 'assign_role'), adminAccountLimiter, adminAccountsController.updateRole);
router.post('/:id/disable', adminAuth, requirePermission('admins', 'manage'), adminAccountLimiter, adminAccountsController.disable);
router.post('/:id/suspend', adminAuth, requirePermission('admins', 'manage'), adminAccountLimiter, adminAccountsController.suspend);
router.post('/:id/reactivate', adminAuth, requirePermission('admins', 'manage'), adminAccountLimiter, adminAccountsController.reactivate);
router.post('/:id/revoke', adminAuth, requirePermission('admins', 'manage'), adminAccountLimiter, adminAccountsController.revoke);

module.exports = router;
