const express = require('express');
const router = express.Router();
const authenticate = require('../middleware/authenticate');

const verifyAdmin = require('../middleware/verifyAdmin');
const { reportPost, listReports, updateReport } = require('../controllers/postReportController');

router.post('/boards/:id/report', reportPost);
router.get('/admin/post-reports', authenticate, verifyAdmin, listReports);
router.patch('/admin/post-reports/:reportId', authenticate, verifyAdmin, updateReport);

module.exports = router;