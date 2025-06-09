const express = require('express');
const { getReviewsByPlace, createReview } = require('../controllers/reviewController');
const router = express.Router();

router.get('/reviews/:placeId', getReviewsByPlace);
router.post('/reviews', createReview);

module.exports = router;
