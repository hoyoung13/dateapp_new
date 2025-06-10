const express = require('express');
const cors = require('cors');
const bodyParser = require("body-parser");
const db = require("./config/db"); // ✅ DB 연결 확인
const dotenv = require('dotenv');
const session = require('express-session');
const passport = require('./config/passport');  // ✅ passport.js 불러오기
const userRoutes = require('./routes/userRoutes'); // ✅ 인증 관련 API
const authRoutes = require('./routes/authRoutes'); // ✅ 이메일/비밀번호 인증 API
const boardRoutes = require("./routes/boardRoutes");
const coupleRoutes = require("./routes/coupleRoutes");
const profileRoutes = require("./routes/profileRoutes"); 
const placeRoutes = require('./routes/placeRoutes');
const adminPlaceRoutes = require('./routes/adminPlaceRoutes');
const zzimRoutes = require('./routes/zzimRoutes');
const courseRoutes = require('./routes/courseRoutes');
const reviewRoutes = require('./routes/reviewRoutes');
const friRoutes = require('./routes/friendRoutes');
const chatRoutes = require('./routes/chatRoomsRoutes');
const aicourseRoutes = require('./routes/aicourseRoutes');

dotenv.config(); // ✅ 환경 변수 로드

const app = express();
app.use(express.json());
app.use(cors());
app.use(express.urlencoded({ extended: true }));

// ✅ 세션 설정 (필수)
app.use(
    session({
        secret: 'your_secret_key',
        resave: false,
        saveUninitialized: false,
    })
);
// ✅ Passport 초기화
app.use(passport.initialize());
app.use(passport.session());
db.connect()
    .then(() => console.log("✅ PostgreSQL 연결 성공!"))
    .catch(err => console.error("❌ PostgreSQL 연결 실패:", err));
console.log("🔍 userRoutes:", userRoutes);
// ✅ API 라우트 등록
app.use("/auth", authRoutes);
if (!userRoutes || Object.keys(userRoutes).length === 0) {
    console.error("❌ userRoutes가 제대로 불러와지지 않았습니다!");
} else {
    app.use('/auth', userRoutes);
}
app.use("/boards", boardRoutes);
app.use("/couple", coupleRoutes);
app.use("/uploads", express.static("uploads"));

// ✅ 프로필 관련 API 라우트 등록
app.use("/profile", profileRoutes); // 🔥 수정됨!

app.use('/places', placeRoutes);
app.use('/admin', adminPlaceRoutes);

app.use('/zzim', zzimRoutes);
app.use('/course', courseRoutes); 
app.use('/api', reviewRoutes);
app.use('/fri', friRoutes);
app.use('/chat', chatRoutes);
app.use('/aicourse', aicourseRoutes);

// ✅ 서버 실행
const PORT = process.env.PORT || 5000;
app.listen(PORT, () => {
    console.log(`✅ 서버 실행 중: http://localhost:${PORT}`);
});
    