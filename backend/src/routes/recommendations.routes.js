const express = require('express');
const router = express.Router();
const jwtAuth = require('../authentication/jwtAuth');
const controller = require('../controllers/unifiedGraphController');
router.get('/feed', jwtAuth, controller.getFeed);
router.post('/events', jwtAuth, controller.event);
module.exports = router;
