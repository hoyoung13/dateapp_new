const express = require('express');
const router = express.Router();
const authenticate = require('../middleware/authenticate');

const verifyAdmin = require('../middleware/verifyAdmin');
const {
  createInquiry,
  listInquiries,
  getInquiry,
  answerInquiry,
} = require('../controllers/inquiryController');

router.post('/inquiries', createInquiry);
router.get('/admin/inquiries', authenticate, verifyAdmin, listInquiries);
router.get('/admin/inquiries/:id', authenticate, verifyAdmin, getInquiry);
router.post('/admin/inquiries/:id/answer', authenticate, verifyAdmin, answerInquiry);

module.exports = router;