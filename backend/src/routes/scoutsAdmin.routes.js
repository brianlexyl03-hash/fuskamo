const express = require('express');
const router = express.Router();
const scoutsAdminController = require('../controllers/scoutsAdminController');
const adminAuth = require('../authentication/adminAuth');
const { requirePermission } = require('../authorization/permissions');
const { adminActionLimiter } = require('../middleware/adminRateLimiter');

router.get('/pending', adminAuth, requirePermission('scouts', 'view'), scoutsAdminController.listPending);
router.post('/:id/approve', adminAuth, requirePermission('scouts', 'approve'), adminActionLimiter, scoutsAdminController.approve);
router.post('/:id/reject', adminAuth, requirePermission('scouts', 'approve'), adminActionLimiter, scoutsAdminController.reject);

module.exports = router;
