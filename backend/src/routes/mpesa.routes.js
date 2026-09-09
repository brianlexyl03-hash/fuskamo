const express = require('express');
const router = express.Router();
const mpesaController = require('../controllers/mpesaController');
const apiKeyAuth = require('../authentication/apiKeyAuth');
const adminAuth = require('../authentication/adminAuth');
const { requirePermission } = require('../authorization/permissions');
const { adminActionLimiter } = require('../middleware/adminRateLimiter');
const { costlyEndpointLimiter } = require('../middleware/rateLimiter');
const { stkPushRules, refundRules, validate } = require('../validators/mpesaValidators');

router.post('/stk-push', apiKeyAuth, costlyEndpointLimiter, stkPushRules, validate, mpesaController.initiateStkPush);
router.get('/status/:checkoutRequestId', apiKeyAuth, mpesaController.getStatus);
router.get('/history/:phoneNumber', apiKeyAuth, mpesaController.getHistory);
// Money movement — real admin auth + the specific payments:refund
// permission, not the public app key. This previously used apiKeyAuth
// (the key baked into every public install) + a role check that read an
// unauthenticated, client-supplied 'x-admin-role' header — anyone with the
// decompiled public key could set that header to 'admin' themselves. That
// gap is why every admin-facing route in this codebase now goes through
// authentication/adminAuth.js instead.
router.post('/refund', adminAuth, requirePermission('payments', 'refund'), adminActionLimiter, refundRules, validate, mpesaController.refund);

// Called by Safaricom's servers, not the app — no API key (Safaricom won't
// send one). Lock down further at the infra/firewall level by whitelisting
// Safaricom's published IP ranges — see docs/deployment.md.
router.post('/callback', mpesaController.handleCallback);

module.exports = router;
