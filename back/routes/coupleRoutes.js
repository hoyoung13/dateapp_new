const express = require("express");
const router = express.Router();
const coupleController = require("../controllers/coupleController");

// ✅ 사용자 검색 추가
router.get("/search-user", coupleController.searchUser);

// ✅ 커플 정보 조회
router.get("/:userId", coupleController.getCoupleInfo);

// ✅ 커플 등록
router.post("/register", coupleController.registerCouple);

// ✅ 커플 해제
router.delete("/delete/:userId", coupleController.deleteCouple);
// ✅ 사귄 날짜 수정 (새로운 엔드포인트 추가)
router.put("/update-date", coupleController.updateStartDate);


module.exports = router;
