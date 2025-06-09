const express = require('express');
const router = express.Router();
const { getFriends,sendFri, getfri,acceptFri,rejectFri,getUserNickname,getSentRequests } = require('../controllers/friendController');
router.get('/friends/:userId', getFriends);

// 1-1) 친구 요청 보내기
// POST /friend_requests 
// Body: { requesterId: number, recipientId: number }
router.post('/', sendFri);

// 1-2) 내게 온 보류 중인 요청 조회
// GET /friend_requests/pending/:userId
router.get('/pending/:userId', getfri);
router.get('/sent/:userId', getSentRequests);

// 1-3) 요청 수락
// POST /friend_requests/:requestId/accept
router.post('/:requestId/accept', acceptFri);

// 1-4) 요청 거절
// POST /friend_requests/:requestId/reject
router.post('/:requestId/reject', rejectFri);

router.get('/search', getUserNickname);

module.exports = router;
