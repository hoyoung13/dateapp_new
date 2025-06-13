const express = require('express');
const router = express.Router();
const verifyAdmin = require('../middleware/verifyAdmin');
const authenticate = require('../middleware/authenticate');

const { reportPlace, listReports, updateReport } = require('../controllers/placeReportController');

router.post('/places/:id/report', reportPlace);
router.get('/admin/place-reports', authenticate, verifyAdmin, listReports);
router.patch('/admin/place-reports/:reportId', authenticate, verifyAdmin, updateReport);

module.exports = router;