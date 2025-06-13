const express = require('express');
const router = express.Router();
const authenticate = require('../middleware/authenticate');
const verifyAdmin = require('../middleware/verifyAdmin');
const ctrl = require('../controllers/shopController');

// user APIs
router.get('/items', ctrl.listItems);
router.post('/purchase', authenticate, ctrl.purchaseItem);
router.get('/purchases/:userId', authenticate, ctrl.getPurchaseHistory);

// admin APIs
router.post('/admin/items', authenticate, verifyAdmin, ctrl.createItem);
router.get('/admin/items', authenticate, verifyAdmin, ctrl.listItems);
router.get('/admin/items/:id', authenticate, verifyAdmin, ctrl.getItem);
router.patch('/admin/items/:id', authenticate, verifyAdmin, ctrl.updateItem);
router.delete('/admin/items/:id', authenticate, verifyAdmin, ctrl.deleteItem);

module.exports = router;