const express = require('express');
const router = express.Router();
const controller = require('../controllers/discoveryController');
const jwtAuth = require('../authentication/jwtAuth');

// Both endpoints need to know WHICH scout/user is calling (to look up their
// preferences, and to attribute events for fraud scoring) — that's per-user
// identity, so this uses jwtAuth (Supabase session JWT), not the shared
// apiKeyAuth secret the rest of the public-facing routes use.
router.get('/feed', jwtAuth, controller.getFeed);
router.post('/events', jwtAuth, controller.logEvent);

module.exports = router;
