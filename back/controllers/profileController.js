const pool = require("../config/db");
const fs = require("fs");
const path = require("path");

// ✅ 프로필 이미지 업로드 및 기존 이미지 삭제
const uploadProfileImage = async (req, res) => {
    const { userId } = req.params;
    if (!req.file) {
        console.error("❌ 파일이 업로드되지 않음");
        return res.status(400).json({ error: "파일이 없습니다." });
    }

    const imageUrl = `/uploads/${req.file.filename}`;

    try {
        console.log(`✅ 업로드된 이미지: ${imageUrl}`);

        // ✅ 기존 프로필 이미지 가져오기
        const result = await pool.query("SELECT profile_image FROM users WHERE id = $1", [userId]);
        
        if (result.rows.length > 0 && result.rows[0].profile_image) {
            const oldImagePath = path.join(__dirname, "..", result.rows[0].profile_image);

            // ✅ 기존 이미지가 존재하면 삭제
            if (fs.existsSync(oldImagePath)) {
                fs.unlinkSync(oldImagePath);
                console.log(`🗑️ 기존 이미지 삭제 완료: ${oldImagePath}`);
            }
        }

        // ✅ 새 이미지 경로 DB 저장
        await pool.query("UPDATE users SET profile_image = $1 WHERE id = $2", [imageUrl, userId]);

        res.status(200).json({ message: "✅ 프로필 이미지 업데이트 성공!", profile_image: imageUrl });
    } catch (error) {
        console.error("❌ 프로필 이미지 업로드 오류:", error);
        res.status(500).json({ error: "서버 오류 발생" });
    }
};

// ✅ 사용자 프로필 정보 가져오기
const getUserProfile = async (req, res) => {
    try {
        const { userId } = req.params;
        const result = await pool.query(
            "SELECT id, nickname, email, name, birth_date, gender, profile_image, points FROM users WHERE id = $1",
            [userId]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({ error: "❌ 사용자 정보를 찾을 수 없습니다." });
        }

        const user = result.rows[0];
        console.log("🔍 프로필 불러온 데이터:", user);  // ✅ 로그 추가

        res.json({
            user: {
                id: user.id,
                nickname: user.nickname,
                email: user.email,
                name: user.name ?? "",
                birth_date: user.birth_date ?? "",
                gender: user.gender ?? "",
                //profile_image: user.profile_image ? `/uploads/${user.profile_image}` : ""
                profile_image: user.profile_image || "",
                points: user.points            }
        });
        console.log("🔍 프로필 정보 반환:", {
            id: user.id,
            nickname: user.nickname,
            email: user.email,
            name: user.name || "🚨 없음",
            birth_date: user.birth_date || "🚨 없음",
            gender: user.gender || "🚨 없음",
            profile_image: user.profile_image,
            points: user.points        });
    } catch (error) {
        console.error("❌ 프로필 불러오기 오류:", error);
        res.status(500).json({ error: "❌ 서버 오류 발생" });
    }
};


// ✅ 모듈 내보내기
module.exports = { uploadProfileImage, getUserProfile };
