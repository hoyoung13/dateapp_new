const express = require("express");
const passport = require('passport');
const router = express.Router();
const { getCoupleInfo } = require("../controllers/coupleController");


// ✅ 구글 로그인 요청
router.get('/google', passport.authenticate('google', { scope: ['profile', 'email'] }));

// ✅ 구글 로그인 콜백
router.get(
    '/google/callback',
    passport.authenticate('google', { failureRedirect: '/' }),
    (req, res) => {
        res.send(`로그인 성공! 환영합니다, ${req.user.username}`);
    }
);

// ✅ 카카오 로그인 요청
router.get('/kakao', passport.authenticate('kakao'));

// ✅ 카카오 로그인 콜백
router.get(
    '/kakao/callback',
    passport.authenticate('kakao', { failureRedirect: '/' }),
    (req, res) => {
        res.send(`로그인 성공! 환영합니다, ${req.user.username}`);
    }
);

// ✅ 로그아웃
router.get('/logout', (req, res) => {
    req.logout(() => {
        res.send('로그아웃 되었습니다.');
    });
});



module.exports = router;