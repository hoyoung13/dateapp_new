const express = require('express');
const router = express.Router();
const verifyAdmin = require('../middleware/verifyAdmin');
const { reportPlace, listReports, updateReport } = require('../controllers/placeReportController');

router.post('/places/:id/report', reportPlace);
router.get('/admin/place-reports', verifyAdmin, listReports);
router.patch('/admin/place-reports/:reportId', verifyAdmin, updateReport);

module.exports = router;