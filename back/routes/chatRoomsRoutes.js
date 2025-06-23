const express = require('express');
const router = express.Router();
const {startchat, getMessages, postMessage,listUserRooms} = require('../controllers/chatRoomsController');
const multer = require('multer');
const path = require('path');
const {startchat, getMessages, postMessage,listUserRooms, uploadMessageImage} = require('../controllers/chatRoomsController');

const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, 'uploads/');
  },
  filename: (req, file, cb) => {
    cb(null, Date.now() + path.extname(file.originalname));
  },
});
const upload = multer({ storage });
// 1:1 방 얻기 또는 생성
// GET /chat/rooms/1on1/:userA/:userB
// routes/fri.js (또는 chatRoutes.js 등)
router.post('/rooms/1on1', startchat);

// 내가 속한 방 목록
// GET /chat/rooms/user/:userId
router.get('/rooms/user/:userId', listUserRooms);

// 방의 메시지 조회
// GET /chat/rooms/:roomId/messages
router.get('/rooms/:roomId/messages', getMessages);

// 방에 메시지 보내기
// POST /chat/rooms/:roomId/messages
// Body: { senderId: number, content: string }
router.post('/rooms/:roomId/messages', postMessage);
router.post('/upload-image', upload.single('image'), uploadMessageImage);

module.exports = router;
