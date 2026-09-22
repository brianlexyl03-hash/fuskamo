const express = require('express');
const router = express.Router();
const mpesaController = require('../controllers/mpesaController');
const adminAuth = require('../authentication/adminAuth');
const { requirePermission } = require('../authorization/permissions');

// Alias under /transactions for a more REST-y resource name — same
// controller as /mpesa/history, kept for API clarity. Was apiKeyAuth-only
// (a real phone-number IDOR, same as /mpesa/history — see the comment
// there); fixed the same way, admin-only, confirmed unused by any client.
router.get('/:phoneNumber', adminAuth, requirePermission('payments', 'view'), mpesaController.getHistory);

module.exports = router;
