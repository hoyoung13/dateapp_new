const express = require('express');
const router = express.Router();
const verifyAdmin = require('../middleware/verifyAdmin');
const { getPlaceRequests, approvePlaceRequest, rejectPlaceRequest } = require('../controllers/adminPlaceController');

router.get('/place-requests', verifyAdmin, getPlaceRequests);
router.post('/place-requests/:id/approve', verifyAdmin, approvePlaceRequest);
router.post('/place-requests/:id/reject', verifyAdmin, rejectPlaceRequest);

module.exports = router;
