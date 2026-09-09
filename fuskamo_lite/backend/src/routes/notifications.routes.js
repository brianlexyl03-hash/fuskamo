const express = require('express');
const router = express.Router();
const controller = require('../controllers/notificationsController');
const apiKeyAuth = require('../authentication/apiKeyAuth');

router.get('/:userId', apiKeyAuth, controller.list);
router.post('/:id/read', apiKeyAuth, controller.markRead);
router.get('/:userId/preferences', apiKeyAuth, controller.getPreferences);
router.put('/:userId/preferences', apiKeyAuth, controller.setPreferences);

module.exports = router;
