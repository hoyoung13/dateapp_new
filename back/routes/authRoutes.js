const express = require('express');
const { registerUser, loginUser,checkNickname,checkEmail,kakaoLogin,getUserProfile } = require('../controllers/authController'); // ✅ 컨트롤러 불러오기
const router = express.Router();

// ✅ 회원가입 API
router.post("/signup", registerUser);

// ✅ 로그인 API
router.post('/login', loginUser);

// ✅ 닉네임 중복 확인
router.get("/check-nickname", checkNickname);

// ✅ 이메일 중복 확인
router.get("/check-email", checkEmail);

// 카카오로 로그인했을때 그 카카오의 닉네임 이메일 users테이블에 저장
router.post("/kakao-login", kakaoLogin);

router.get("/profile/:userId", getUserProfile);

module.exports = router;
