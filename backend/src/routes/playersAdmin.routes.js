const express = require('express');
const router = express.Router();
const playersAdminController = require('../controllers/playersAdminController');
const adminAuth = require('../authentication/adminAuth');
const { requirePermission } = require('../authorization/permissions');
const { adminActionLimiter } = require('../middleware/adminRateLimiter');

// Every route requires a real, verified Supabase admin session (adminAuth)
// AND the specific permission for what it does (requirePermission) — see
// docs/admin-access.md. There is no shared-key fallback anymore.
router.get('/pending', adminAuth, requirePermission('players', 'view'), playersAdminController.listPending);
router.post('/:id/approve', adminAuth, requirePermission('players', 'approve'), adminActionLimiter, playersAdminController.approve);
router.post('/:id/reject', adminAuth, requirePermission('players', 'approve'), adminActionLimiter, playersAdminController.reject);

module.exports = router;
