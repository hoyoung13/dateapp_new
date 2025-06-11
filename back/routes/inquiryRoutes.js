const express = require('express');
const router = express.Router();
const verifyAdmin = require('../middleware/verifyAdmin');
const {
  createInquiry,
  listInquiries,
  getInquiry,
  answerInquiry,
} = require('../controllers/inquiryController');

router.post('/inquiries', createInquiry);
router.get('/admin/inquiries', verifyAdmin, listInquiries);
router.get('/admin/inquiries/:id', verifyAdmin, getInquiry);
router.post('/admin/inquiries/:id/answer', verifyAdmin, answerInquiry);

module.exports = router;
