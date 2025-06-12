const express = require('express');
const router = express.Router();
const verifyAdmin = require('../middleware/verifyAdmin');
const { reportPost, listReports, updateReport } = require('../controllers/postReportController');

router.post('/boards/:id/report', reportPost);
router.get('/admin/post-reports', verifyAdmin, listReports);
router.patch('/admin/post-reports/:reportId', verifyAdmin, updateReport);

module.exports = router;
