
const express = require('express');
const router = express.Router();

const { createCourse,getCoursesByUser,updateCourse,deleteCourse,getAllCourses } = require('../controllers/courseController');

router.post('/courses', createCourse);
router.get('/user_courses/:user_id', getCoursesByUser);
router.put('/courses/:id', updateCourse);

router.delete('/courses/:id', deleteCourse);
router.get('/allcourse', getAllCourses);

module.exports = router;
