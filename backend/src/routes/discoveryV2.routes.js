const express = require('express');
const router = express.Router();
const controller = require('../controllers/playerDiscoveryV2Controller');
const jwtAuth = require('../authentication/jwtAuth');
router.get('/feed', jwtAuth, controller.getFeed);
router.post('/events', jwtAuth, controller.logEvent);
module.exports = router;
