const express = require('express');
const router = express.Router();
const authenticate = require('../middleware/authenticate');

const verifyAdmin = require('../middleware/verifyAdmin');
const { getPlaceRequests, approvePlaceRequest, rejectPlaceRequest } = require('../controllers/adminPlaceController');
const { updatePlace, getPlaceByIdAdmin } = require('../controllers/placeController');

router.get('/place-requests', authenticate, verifyAdmin, getPlaceRequests);
router.post('/place-requests/:id/approve', authenticate, verifyAdmin, approvePlaceRequest);
router.post('/place-requests/:id/reject', authenticate, verifyAdmin, rejectPlaceRequest);
router.get('/places/:id', authenticate, verifyAdmin, getPlaceByIdAdmin);
router.patch('/places/:id', authenticate, verifyAdmin, updatePlace);
module.exports = router;