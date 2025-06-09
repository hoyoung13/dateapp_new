const express = require("express");
const multer = require("multer");
const path = require("path");
const { uploadProfileImage, getUserProfile } = require("../controllers/profileController");

const router = express.Router();

// ✅ Multer 설정 (uploads 폴더에 저장)
const storage = multer.diskStorage({
    destination: (req, file, cb) => {
        cb(null, "uploads/"); // 이미지 저장 경로
    },
    filename: (req, file, cb) => {
        cb(null, Date.now() + path.extname(file.originalname)); // 파일명 설정
    }
});

const upload = multer({ storage });

// ✅ 프로필 이미지 업로드 API
router.post("/upload-profile-image/:userId", upload.single("image"), uploadProfileImage);

// ✅ 사용자 프로필 정보 가져오기 API
router.get("/:userId", getUserProfile);

module.exports = router;
