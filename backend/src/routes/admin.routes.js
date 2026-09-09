const express = require('express');
const router = express.Router();
const adminStatsController = require('../controllers/adminStatsController');
const adminAuth = require('../authentication/adminAuth');
const { requirePermission } = require('../authorization/permissions');

// Overview dashboard + transaction history + audit log — see
// admin-web/index.html and docs/admin-access.md.
router.get('/stats', adminAuth, requirePermission('analytics', 'view'), adminStatsController.getOverview);
router.get('/transactions', adminAuth, requirePermission('payments', 'view'), adminStatsController.listTransactions);
router.get('/audit-logs', adminAuth, requirePermission('audit', 'view'), adminStatsController.listAuditLogs);

module.exports = router;
