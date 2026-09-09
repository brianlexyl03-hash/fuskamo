const router = require('express').Router();
const controller = require('../controllers/videoInfrastructureController');
const jwtAuth = require('../authentication/jwtAuth');

router.get('/status', controller.status);
router.post('/prepare', jwtAuth, controller.prepare);

module.exports = router;
