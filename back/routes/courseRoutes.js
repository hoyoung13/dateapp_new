
const express = require('express');
const router = express.Router();

const { createCourse,getCoursesByUser,deleteCourse,getAllCourses } = require('../controllers/courseController');

router.post('/courses', createCourse);
router.get('/user_courses/:user_id', getCoursesByUser);
router.delete('/courses/:id', deleteCourse);
router.get('/allcourse', getAllCourses);

module.exports = router;
