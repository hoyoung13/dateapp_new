const express = require('express');
const router = express.Router();
const authenticate = require('../middleware/authenticate');
const verifyAdmin = require('../middleware/verifyAdmin');
const ctrl = require('../controllers/shopController');
const multer = require('multer');
const path = require('path');

const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, 'uploads/');
  },
  filename: (req, file, cb) => {
    cb(null, Date.now() + path.extname(file.originalname));
  },
});
const upload = multer({ storage });
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
router.post(
    '/admin/upload-item-image',
    authenticate,
    verifyAdmin,
    upload.single('image'),
    ctrl.uploadItemImage
  );
module.exports = router;