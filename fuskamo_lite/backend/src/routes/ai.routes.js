const express = require('express');
const router = express.Router();
const aiController = require('../controllers/aiController');
const apiKeyAuth = require('../authentication/apiKeyAuth');
const { costlyEndpointLimiter } = require('../middleware/rateLimiter');

router.post('/summarize-player', apiKeyAuth, costlyEndpointLimiter, aiController.summarizePlayer);

module.exports = router;
