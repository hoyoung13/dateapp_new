const express = require('express');
const router = express.Router();
const { getPointHistory } = require('../controllers/pointController');

router.get('/points/history/:userId', getPointHistory);

module.exports = router;