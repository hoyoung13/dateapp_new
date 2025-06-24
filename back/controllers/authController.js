const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const pool = require('../config/db');

// ✅ 회원가입
const registerUser = async (req, res) => {
    console.log("📥 회원가입 요청 도착! 데이터:", req.body);
    try {
        let { nickname, email, password, name, birth_date, gender } = req.body;
        gender = gender === "male" ? "남성" : "여성";

        const hashedPassword = await bcrypt.hash(password, 10);

        // 여기는 회원가입 기본정보 저장
        const newUserResult = await pool.query(
            "INSERT INTO users (nickname, email, password, name, birth_date, gender, points) VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING *",
            [nickname, email, hashedPassword, name, birth_date, gender, 0]
        );
        const newUser = newUserResult.rows[0];

        // 여기는 기본 찜목록 생성하는거
        const defaultCollectionResult = await pool.query(
            "INSERT INTO collections (user_id, collection_name, description, is_public) VALUES ($1, $2, $3, $4) RETURNING *",
            [newUser.id, "찜목록", "기본 찜 목록", false]
        );
        const defaultCollection = defaultCollectionResult.rows[0];

        res.status(201).json({ 
            message: "✅ 회원가입 성공!", 
            user: newUser,
            defaultCollection: defaultCollection
        });
    } catch (err) {
        console.error(err.message);
        res.status(500).json({ error: "❌ 서버 오류 발생" });
    }
};


// ✅ 로그인
const loginUser = async (req, res) => {
    try {
      const { email, password } = req.body;
      const result = await pool.query(
        "SELECT id, nickname, email, name, birth_date, gender, profile_image, password, is_admin, points FROM users WHERE email = $1",
        [email]
      );
  
      if (result.rows.length === 0) {
        return res.status(400).json({ error: "❌ 이메일이 존재하지 않습니다." });
      }
  
      const user = result.rows[0];
      console.log("🔍 로그인한 유저 정보:", user);
  
      const isMatch = await bcrypt.compare(password, user.password);
      if (!isMatch) {
        return res.status(400).json({ error: "❌ 비밀번호가 틀렸습니다." });
      }
  
      // 토큰 payload에 is_admin 정보를 담아서 발급
      const token = jwt.sign(
        { userId: user.id, email: user.email, isAdmin: user.is_admin },
        process.env.JWT_SECRET || "your_secret_key",
        { expiresIn: "1h" }
      );
  
      // 프로필 이미지 URL 처리 (원래대로 유지)
      let profileImage = user.profile_image;
      if (profileImage && !profileImage.startsWith("/uploads/")) {
        profileImage = `/uploads/${profileImage}`;
      }
  
      // 응답에도 isAdmin 필드를 포함해서 돌려준다
      res.json({
        message: "✅ 로그인 성공!",
        token,
        user: {
          id: user.id,
          nickname: user.nickname,
          email: user.email,
          name: user.name || "",
          birth_date: user.birth_date || "",
          gender: user.gender || "",
          profile_image: profileImage || "",
          isAdmin: user.is_admin,   // 관리자 여부
          points: user.points
                }
      });
  
      console.log("🔍 로그인한 유저 정보:", {
        id: user.id,
        nickname: user.nickname,
        email: user.email,
        name: user.name || "🚨 없음",
        birth_date: user.birth_date || "🚨 없음",
        gender: user.gender || "🚨 없음",
        profile_image: user.profile_image,
        isAdmin: user.is_admin,
        points: user.points      });
    } catch (error) {
      console.error(error.message);
      res.status(500).json({ error: "❌ 서버 오류 발생" });
    }
  };
/*const loginUser = async (req, res) => {
    try {
        const { email, password } = req.body;
        const result = await pool.query(
            "SELECT id, nickname, email, name, birth_date, gender, profile_image, password FROM users WHERE email = $1",
            [email]
        );

        if (result.rows.length === 0) {
            return res.status(400).json({ error: "❌ 이메일이 존재하지 않습니다." });
        }

        const user = result.rows[0];
        console.log("🔍 로그인한 유저 정보:", user); // ✅ 로그 추가

        const isMatch = await bcrypt.compare(password, user.password);

        if (!isMatch) {
            return res.status(400).json({ error: "❌ 비밀번호가 틀렸습니다." });
        }

        const token = jwt.sign(
            { userId: user.id, email: user.email },
            process.env.JWT_SECRET || "your_secret_key",
            { expiresIn: "1h" }
        );

        // ✅ 프로필 이미지 URL 설정 (중복 방지)
        let profileImage = user.profile_image;
        if (profileImage && !profileImage.startsWith("/uploads/")) {
            profileImage = `/uploads/${profileImage}`;
        }

        res.json({
            message: "✅ 로그인 성공!",
            token,
            user: {
                id: user.id,
                nickname: user.nickname,
                email: user.email,
                name: user.name || "",  // ✅ name 추가
                birth_date: user.birth_date || "",  // ✅ birth_date 추가
                gender: user.gender || "",

                profile_image: user.profile_image ? user.profile_image : ""  
            }
        });
        console.log("🔍 로그인한 유저 정보:", {
            id: user.id,
            nickname: user.nickname,
            email: user.email,
            name: user.name || "🚨 없음",  // ✅ 디버깅 로그 추가
            birth_date: user.birth_date || "🚨 없음",
            gender: user.gender || "🚨 없음",
            profile_image: user.profile_image
        });
    } catch (error) {
        console.error(error.message);
        res.status(500).json({ error: "❌ 서버 오류 발생" });
    }
};*/



// ✅ 닉네임 중복 확인
const checkNickname = async (req, res) => {
    const { nickname } = req.query;
    const result = await pool.query("SELECT * FROM users WHERE nickname = $1", [nickname]);

    if (result.rows.length > 0) {
        return res.json({ available: false, message: "❌ 이미 사용 중인 닉네임입니다." });
    }
    res.json({ available: true, message: "✅ 사용 가능한 닉네임입니다." });
};

// ✅ 이메일 중복 확인
const checkEmail = async (req, res) => {
    const { email } = req.query;
    const result = await pool.query("SELECT * FROM users WHERE email = $1", [email]);

    if (result.rows.length > 0) {
        return res.json({ available: false, message: "❌ 이미 사용 중인 이메일입니다." });
    }
    res.json({ available: true, message: "✅ 사용 가능한 이메일입니다." });
};

// ✅ 카카오 로그인
const kakaoLogin = async (req, res) => {
    const { email, nickname, kakao_id } = req.body;

    if (!kakao_id) {
        return res.status(400).json({ error: "카카오 ID가 필요합니다." });
    }

    try {
        const existingUserQuery = `SELECT * FROM users WHERE kakao_id = $1`;
        const existingUserResult = await pool.query(existingUserQuery, [kakao_id]);

        if (existingUserResult.rows.length > 0) {
            console.log("✅ 기존 카카오 유저 로그인:", email);
            return res.status(200).json({ message: "기존 사용자 로그인", user: existingUserResult.rows[0] });
        } else {
            console.log("✅ 신규 카카오 유저 등록:", email || "이메일 없음");
            const hashedPassword = await bcrypt.hash(kakao_id.toString(), 10);

            const insertUserQuery = `
                INSERT INTO users (email, nickname, password, kakao_id)
                VALUES ($1, $2, $3, $4) RETURNING *`;
            const newUser = await pool.query(insertUserQuery, [email || null, nickname, hashedPassword, kakao_id]);

            return res.status(201).json({ message: "새 사용자 등록 완료", user: newUser.rows[0] });
        }
    } catch (error) {
        console.error("❌ 카카오 로그인 처리 중 오류:", error);
        res.status(500).json({ error: "서버 오류 발생" });
    }
};
// ✅ 사용자 프로필 조회
const getUserProfile = async (req, res) => {
    const { userId } = req.params;

    try {
        const result = await pool.query(
            "SELECT id, name, nickname, email, birth_date, gender, profile_image, points FROM users WHERE id = $1",
            [userId]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({ error: "사용자를 찾을 수 없습니다." });
        }

        res.status(200).json({ user: result.rows[0] });
    } catch (error) {
        console.error("❌ 사용자 프로필 조회 오류:", error);
        res.status(500).json({ error: "서버 오류 발생" });
    }
};


// ✅ 모듈 내보내기 (함수를 객체로 묶어서 정리)
module.exports = {
    registerUser,
    loginUser,
    checkNickname,
    checkEmail,
    kakaoLogin,
    getUserProfile, 

};
