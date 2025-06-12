const express = require('express');
const router = express.Router();
const verifyAdmin = require('../middleware/verifyAdmin');
const { getPlaceRequests, approvePlaceRequest, rejectPlaceRequest } = require('../controllers/adminPlaceController');
const { updatePlace, getPlaceByIdAdmin } = require('../controllers/placeController');

router.get('/place-requests', verifyAdmin, getPlaceRequests);
router.post('/place-requests/:id/approve', verifyAdmin, approvePlaceRequest);
router.post('/place-requests/:id/reject', verifyAdmin, rejectPlaceRequest);
router.get('/places/:id', verifyAdmin, getPlaceByIdAdmin);
router.patch('/places/:id', verifyAdmin, updatePlace);

module.exports = router;