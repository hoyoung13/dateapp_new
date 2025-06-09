const pool = require("../config/db");

// ✅ 커플 정보 조회 (양방향 검색)
const getCoupleInfo = async (req, res) => {
    let { userId } = req.params;
    
    // userId가 숫자인지 체크
    if (isNaN(userId)) {
        return res.status(400).json({ error: "잘못된 요청: userId는 숫자여야 합니다." });
    }

    userId = parseInt(userId, 10); // 🔥 userId를 정수(Integer)로 변환

    try {
        const query = `
            SELECT 
                c.start_date, 
                u2.id AS partner_id, 
                u2.name AS partner_name, 
                u2.nickname AS partner_nickname, 
                u2.birth_date AS partner_birth_date
            FROM couples c
            JOIN users u1 ON (c.user_id = u1.id OR c.partner_id = u1.id)
            JOIN users u2 ON (c.user_id = u2.id OR c.partner_id = u2.id)
            WHERE (c.user_id = $1 OR c.partner_id = $1)
            AND u2.id != $1  -- 상대방 정보만 가져오기
        `;

        const result = await pool.query(query, [userId]);

        if (result.rows.length === 0) {
            return res.status(404).json({ error: "등록된 커플이 없습니다." });
        }

        res.status(200).json({ couple: result.rows[0] });
    } catch (error) {
        console.error("❌ 커플 정보 가져오기 오류:", error);
        res.status(500).json({ error: "서버 오류 발생" });
    }
};
const updateStartDate = async (req, res) => {
    const { user_id, start_date } = req.body;

    if (!user_id || !start_date) {
        return res.status(400).json({ error: "잘못된 요청: user_id와 start_date가 필요합니다." });
    }

    try {
        const updateQuery = `
            UPDATE couples 
            SET start_date = $1 
            WHERE user_id = $2 OR partner_id = $2
        `;

        await pool.query(updateQuery, [start_date, user_id]);

        res.status(200).json({ message: "✅ 사귄 날짜 수정 완료!" });
    } catch (error) {
        console.error("❌ 사귄 날짜 수정 오류:", error);
        res.status(500).json({ error: "서버 오류 발생" });
    }
};


// ✅ 커플 등록
const registerCouple = async (req, res) => {
    const { user_id, partner_id } = req.body;

    try {
        // 이미 등록된 커플인지 확인
        const checkQuery = "SELECT * FROM couples WHERE user_id = $1 OR partner_id = $1";
        const checkResult = await pool.query(checkQuery, [user_id]);

        if (checkResult.rows.length > 0) {
            return res.status(400).json({ error: "이미 등록된 커플이 있습니다." });
        }

        // 커플 등록
        const insertQuery = "INSERT INTO couples (user_id, partner_id, start_date) VALUES ($1, $2, NOW()) RETURNING *";
        const newCouple = await pool.query(insertQuery, [user_id, partner_id]);

        res.status(201).json({ message: "✅ 커플 등록 성공!", couple: newCouple.rows[0] });
    } catch (error) {
        console.error("❌ 커플 등록 오류:", error);
        res.status(500).json({ error: "서버 오류 발생" });
    }
};

// ✅ 커플 해제
const deleteCouple = async (req, res) => {
    const { userId } = req.params;

    try {
        const deleteQuery = "DELETE FROM couples WHERE user_id = $1 OR partner_id = $1";
        await pool.query(deleteQuery, [userId]);

        res.json({ message: "✅ 커플 해제 완료!" });
    } catch (error) {
        console.error("❌ 커플 해제 오류:", error);
        res.status(500).json({ error: "서버 오류 발생" });
    }
};

// ✅ 사용자 검색 (닉네임 + 이메일)
const searchUser = async (req, res) => {
    const { nickname, email } = req.query;

    try {
        const result = await pool.query(
            "SELECT id, nickname, email FROM users WHERE nickname = $1 AND email = $2",
            [nickname, email]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({ error: "사용자를 찾을 수 없습니다." });
        }

        res.status(200).json({ user: result.rows[0] });
    } catch (error) {
        console.error("❌ 사용자 검색 오류:", error);
        res.status(500).json({ error: "서버 오류 발생" });
    }
};

// ✅ 🚨 여기서 module.exports를 한 번만 호출하도록 수정
module.exports = { getCoupleInfo,updateStartDate , registerCouple, deleteCouple, searchUser };
