const express = require('express');
const router = express.Router();
const controller = require('../controllers/searchController');

// Public universal search (players, scouts, groups). No API key required —
// matches the web-app client, which calls this before a user has signed in.
router.get('/', controller.search);

module.exports = router;
