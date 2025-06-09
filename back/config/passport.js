const passport = require('passport');
/*const GoogleStrategy = require('passport-google-oauth20').Strategy;*/
const KakaoStrategy = require('passport-kakao').Strategy;
const pool = require('./db'); // PostgreSQL 연결
const dotenv = require('dotenv');
dotenv.config();  // ✅ 환경 변수 로드


// ✅ 구글 로그인 설정
/*passport.use(
    new GoogleStrategy(
        {
            clientID: process.env.GOOGLE_CLIENT_ID,
            clientSecret: process.env.GOOGLE_CLIENT_SECRET,
            callbackURL: process.env.GOOGLE_CALLBACK_URL,
        },
        async (accessToken, refreshToken, profile, done) => {
            try {
                const { id, displayName, emails } = profile;
                const email = emails[0].value;

                // DB에 사용자 저장 또는 조회
                let user = await pool.query("SELECT * FROM users WHERE email = $1", [email]);

                if (user.rows.length === 0) {
                    // 신규 사용자 저장
                    const newUser = await pool.query(
                        "INSERT INTO users (username, email, password) VALUES ($1, $2, $3) RETURNING *",
                        [displayName, email, id]
                    );
                    user = newUser.rows[0];
                } else {
                    user = user.rows[0];
                }

                return done(null, user);
            } catch (error) {
                return done(error, null);
            }
        }
    )
);*/

// ✅ 카카오 로그인 설정
passport.use(
    new KakaoStrategy(
        {
            clientID: process.env.KAKAO_CLIENT_ID,
            clientSecret: process.env.KAKAO_CLIENT_SECRET,
            callbackURL: process.env.KAKAO_CALLBACK_URL,
        },
        async (accessToken, refreshToken, profile, done) => {
            try {
                const { id, username } = profile;
                const email = profile._json.kakao_account?.email || `${id}@kakao.com`;

                // DB에 사용자 저장 또는 조회
                let user = await pool.query("SELECT * FROM users WHERE email = $1", [email]);

                if (user.rows.length === 0) {
                    // 신규 사용자 저장
                    const newUser = await pool.query(
                        "INSERT INTO users (username, email, password) VALUES ($1, $2, $3) RETURNING *",
                        [username, email, id]
                    );
                    user = newUser.rows[0];
                } else {
                    user = user.rows[0];
                }

                return done(null, user);
            } catch (error) {
                return done(error, null);
            }
        }
    )
);

// ✅ 세션 설정 (선택 사항)
passport.serializeUser((user, done) => {
    done(null, user.id);
});

passport.deserializeUser(async (id, done) => {
    try {
        const user = await pool.query("SELECT * FROM users WHERE id = $1", [id]);
        done(null, user.rows[0]);
    } catch (error) {
        done(error, null);
    }
});

module.exports = passport;
