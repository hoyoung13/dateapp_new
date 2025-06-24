const express = require('express');
const router = express.Router();
const {
    generateAICourse,
    generateFixedCourse,
    saveAICourse,
    recommendPlaces,
    aiPlaceRecommend,
  } = require('../controllers/aicourseController'); 

router.post('/generate', generateAICourse);
router.get('/fixed', generateFixedCourse);

router.post('/save', saveAICourse);
router.post('/ai', recommendPlaces);
router.post('/aiplace', aiPlaceRecommend);
module.exports = router;



