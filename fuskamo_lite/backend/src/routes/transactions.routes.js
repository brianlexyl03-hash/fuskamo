const express = require('express');
const router = express.Router();
const mpesaController = require('../controllers/mpesaController');
const apiKeyAuth = require('../authentication/apiKeyAuth');

// Alias under /transactions for a more REST-y resource name — same
// controller as /mpesa/history, kept for API clarity.
router.get('/:phoneNumber', apiKeyAuth, mpesaController.getHistory);

module.exports = router;
