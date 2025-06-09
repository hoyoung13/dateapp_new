const { Pool } = require('pg');
const dotenv = require('dotenv');

dotenv.config();  // ✅ .env 파일 로드

const pool = new Pool({
    user: process.env.DB_USER,
    host: process.env.DB_HOST,
    database: process.env.DB_NAME,
    password: process.env.DB_PASSWORD,
    port: process.env.DB_PORT,
    connectionString: process.env.DATABASE_URL, // .env 파일에 DATABASE_URL 설정

  });

pool.connect()
    .then(() => console.log("✅ PostgreSQL 연결 성공!"))
    .catch(err => console.error("❌ PostgreSQL 연결 실패:", err));
// 🚨 여기 추가 (query 실행 방식 통일)
const query = async (text, params) => {
  const client = await pool.connect();
  try {
      const result = await client.query(text, params);
      return result;
  } catch (err) {
      console.error("❌ PostgreSQL Query Error:", err);
      throw err;
  } finally {
      client.release();
  }
};
module.exports = pool;  // ✅ 다른 파일에서 불러와서 사용 가능
