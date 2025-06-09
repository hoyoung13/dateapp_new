// back/routes/zzimRoutes.js
const express = require('express');
const router = express.Router();
const { createCollection,getCollectionsByUser,deleteCollection,addPlaceToCollection,getPlacesInCollection } = require('../controllers/zzimController');

// POST /zzim/collections -> 새로운 컬렉션 추가 API
router.post('/collections', createCollection);
router.get('/collections/:user_id', getCollectionsByUser);
router.delete('/collections/:collection_id', deleteCollection);
router.post('/collection_places', addPlaceToCollection);
router.get('/collection_places/:collection_id', getPlacesInCollection);

module.exports = router;
