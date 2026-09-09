const express = require('express');
const router = express.Router();
const adminAuthController = require('../controllers/adminAuthController');
const adminAuth = require('../authentication/adminAuth');
const { adminSessionLimiter } = require('../middleware/adminRateLimiter');

// Every route here is self-service — the signed-in admin acting on their
// own account/sessions, not on anyone else's. See adminAccounts.routes.js
// for Super-Admin-on-others operations.
router.get('/me', adminAuth, adminAuthController.me);
router.post('/mfa/confirm', adminAuth, adminAuthController.confirmMfa);
router.post('/mfa/disable', adminAuth, adminAuthController.disableMfa);
router.get('/sessions', adminAuth, adminSessionLimiter, adminAuthController.listSessions);
router.delete('/sessions/:id', adminAuth, adminSessionLimiter, adminAuthController.revokeSession);
router.post('/sessions/revoke-all', adminAuth, adminSessionLimiter, adminAuthController.revokeAllSessions);

module.exports = router;
