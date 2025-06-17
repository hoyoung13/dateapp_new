// back/routes/zzimRoutes.js
const express = require('express');
const router = express.Router();
const {
    createCollection,
    getCollectionsByUser,
    getPublicCollections,
    favoriteCollection,
    deleteCollection,
    updateCollection,
    addPlaceToCollection,
    getPlacesInCollection,
    deletePlaceFromCollection,
  } = require('../controllers/zzimController');// POST /zzim/collections -> 새로운 컬렉션 추가 API
router.post('/collections', createCollection);
router.get('/collections/:user_id', getCollectionsByUser);
router.get('/public_collections', getPublicCollections);
router.post('/collections/:collection_id/favorite', favoriteCollection);

router.delete('/collections/:collection_id', deleteCollection);
router.patch('/collections/:collection_id', updateCollection);

router.post('/collection_places', addPlaceToCollection);
router.get('/collection_places/:collection_id', getPlacesInCollection);
router.delete('/collection_places/:collection_id/:place_id', deletePlaceFromCollection);


module.exports = router;
