const express = require('express');
const router = express.Router();
const externalController = require('../controllers/externalController');

router.get('/countries', externalController.getCountries);

module.exports = router;
