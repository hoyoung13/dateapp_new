// back/controllers/placeController.js
const pool = require('../config/db');
const nodemailer = require('nodemailer');

const transporter = nodemailer.createTransport({
  sendmail: true,
  newline: 'unix',
  path: '/usr/sbin/sendmail'
});
const createPlace = async (req, res) => {
  console.log("▶️ [SERVER] req.body.price_info =", JSON.stringify(req.body.price_info, null, 2));
  console.log("▶️ [SERVER] req.body.operating_hours =", JSON.stringify(req.body.operating_hours, null, 2));

  try {
    let {
      user_id,
      place_name,
      description,
      address,
      phone,
      main_category,
      sub_category,
      hashtags,
      images,
      operating_hours,
      price_info,
      with_who,
      purpose,
      mood
    } = req.body;
    const isAdmin = req.body.is_admin === true || req.body.isAdmin === true;
    const isApproved = isAdmin ? true : false;
    // 문자열 형태일 때만 JSON.parse
    if (typeof operating_hours === "string") {
      try {
        operating_hours = JSON.parse(operating_hours);
      } catch {
        operating_hours = null;
      }
    }
    if (typeof price_info === "string") {
      try {
        price_info = JSON.parse(price_info);
      } catch {
        price_info = null;
      }
    }

   // ───────────────▶️ 수정 포인트:
   // JS 객체 배열을 Postgres JSONB로 전달하려면 반드시 JSON.stringify 해 줘야 함
   const operatingHoursJson = operating_hours
     ? JSON.stringify(operating_hours)
     : null;
   const priceInfoJson = price_info
     ? JSON.stringify(price_info)
     : null;

    const query = `
       INSERT INTO place_info
        (user_id, place_name, description, address, phone,
         main_category, sub_category, hashtags, images, operating_hours, price_info, with_who,
      purpose,
      mood,
      is_approved)
      VALUES
        ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15)
      RETURNING *;
    `;

    const values = [
      user_id,             // $1
      place_name,          // $2
      description,         // $3
      address,             // $4
      phone,               // $5
      main_category,       // $6
      sub_category,        // $7
      hashtags,            // $8  (JS 배열)
      images,              // $9  (JS 배열)
     
      operatingHoursJson,  // $10 (JSON 문자열 or null)
      priceInfoJson,
      with_who,
      purpose,
      mood,
      isApproved     // $11 (JSON 문자열 or null)
    ];

    console.log("▶️ [SERVER] INSERT values =", JSON.stringify(values, null, 2));

    const result = await pool.query(query, values);
    if (!isApproved) {
      try {
        await transporter.sendMail({
          from: 'no-reply@example.com',
          to: 'ad1234@ad1234',
          subject: 'New place suggestion',
          text: `${place_name} has been submitted for approval.`
        });
      } catch (err) {
        console.error('Email send failed:', err);
      }
    }
    res.status(201).json({ message: "Place created", place: result.rows[0] });
  } catch (error) {
    console.error("Error creating place:", error);
    res.status(500).json({ error: "Server error" });
  }
};


const getPlaces = async (req, res) => {
  try {
    const sql = `
      SELECT
        p.*,
        COALESCE(AVG(r.rating), 0)::numeric(2,1)   AS rating_avg,
        COUNT(r.*)                                 AS review_count,
        COALESCE(COUNT(cp.*), 0)                   AS favorite_count
      FROM place_info p
      -- 리뷰 합계/카운트
      LEFT JOIN review r  ON r.place_id = p.id
      -- 찜(즐겨찾기) 합계
      LEFT JOIN collection_places cp  ON cp.place_id = p.id
      WHERE p.is_approved = true
      GROUP BY p.id
      ORDER BY p.id
    `;
    const result = await pool.query(sql);
    res.status(200).json(result.rows);
  } catch (error) {
    console.error("Error fetching places:", error);
    res.status(500).json({ error: "Server error" });
  }
};
const getPlaceById = async (req, res) => {
  try {
    const { id } = req.params;

    // 1) place_views 테이블에 “조회 기록”을 하나 남김
    await pool.query(
      `INSERT INTO place_views (place_id) VALUES ($1)`,
      [id]
    );

    const sql = `
      SELECT
        p.*,
        COALESCE(AVG(r.rating), 0)::numeric(2,1) AS rating_avg,
        COUNT(r.*)                     AS review_count
      FROM place_info p
      LEFT JOIN review r
        ON r.place_id = p.id
      WHERE p.id = $1 AND p.is_approved = true
      GROUP BY p.id;
    `;
    const result = await pool.query(sql, [id]);
    if (result.rows.length === 0) {
      return res.status(404).json({ error: "Place not found" });
    }
    res.status(200).json(result.rows[0]);

  } catch (error) {
    console.error("Error fetching place by ID:", error);
    res.status(500).json({ error: "Server error" });
  }
};

// 관리자용 상세 조회 (승인 여부 무시)
const getPlaceByIdAdmin = async (req, res) => {
  try {
    const { id } = req.params;
    const { rows } = await pool.query('SELECT * FROM place_info WHERE id=$1', [id]);
    if (!rows.length) return res.status(404).json({ error: 'Place not found' });
    res.json(rows[0]);
  } catch (err) {
    console.error('getPlaceByIdAdmin error:', err);
    res.status(500).json({ error: 'Server error' });
  }
};

// 장소 정보 수정
const updatePlace = async (req, res) => {
  const id = parseInt(req.params.id, 10);
  if (!id) return res.status(400).json({ error: 'Invalid id' });

  let {
    place_name,
    description,
    address,
    phone,
    main_category,
    sub_category,
    hashtags,
    images,
    operating_hours,
    price_info,
    with_who,
    purpose,
    mood
  } = req.body;

  if (typeof operating_hours === 'string') {
    try { operating_hours = JSON.parse(operating_hours); } catch { operating_hours = null; }
  }
  if (typeof price_info === 'string') {
    try { price_info = JSON.parse(price_info); } catch { price_info = null; }
  }

  const opJson = operating_hours ? JSON.stringify(operating_hours) : null;
  const priceJson = price_info ? JSON.stringify(price_info) : null;

  const fields = [];
  const values = [];
  const add = (col, val) => { fields.push(`${col}=$${values.length + 1}`); values.push(val); };

  if (place_name !== undefined) add('place_name', place_name);
  if (description !== undefined) add('description', description);
  if (address !== undefined) add('address', address);
  if (phone !== undefined) add('phone', phone);
  if (main_category !== undefined) add('main_category', main_category);
  if (sub_category !== undefined) add('sub_category', sub_category);
  if (hashtags !== undefined) add('hashtags', hashtags);
  if (images !== undefined) add('images', images);
  if (operating_hours !== undefined) add('operating_hours', opJson);
  if (price_info !== undefined) add('price_info', priceJson);
  if (with_who !== undefined) add('with_who', with_who);
  if (purpose !== undefined) add('purpose', purpose);
  if (mood !== undefined) add('mood', mood);

  if (!fields.length) {
    return res.status(400).json({ error: 'No fields to update' });
  }

  const query = `UPDATE place_info SET ${fields.join(', ')} WHERE id=$${values.length + 1} RETURNING *`;
  values.push(id);

  try {
    const { rows } = await pool.query(query, values);
    res.json({ place: rows[0] });
  } catch (err) {
    console.error('updatePlace error:', err);
    res.status(500).json({ error: 'Server error' });
  }
};

/*const getPlaceById = async (req, res) => {
  try {
    const { id } = req.params;

    // place_info에 review 테이블을 LEFT JOIN해서 평균 평점(rating_avg)과 리뷰 개수(review_count) 계산
    const sql = `
      SELECT
        p.*,
        COALESCE(AVG(r.rating), 0)::numeric(2,1)   AS rating_avg,
        COUNT(r.*)                                 AS review_count
      FROM place_info p
      LEFT JOIN review r
        ON r.place_id = p.id
      WHERE p.id = $1
      GROUP BY p.id
    `;
    const result = await pool.query(sql, [id]);

    if (result.rows.length === 0) {
      return res.status(404).json({ error: "Place not found" });
    }

    // 이제 result.rows[0] 안에 rating_avg, review_count 필드가 포함됩니다.
    res.status(200).json(result.rows[0]);
  } catch (error) {
    console.error("Error fetching place:", error);
    res.status(500).json({ error: "Server error" });
  }
};*/

async function getFilteredPlaces(req, res) {
  try {
    // 쿼리 파라미터 읽기
    const { city, district, neighborhood, category } = req.query;

    // 동적 WHERE 절 조립 준비
    const conditions = [];
    const values = [];

    // main_category 필터 (category 파라미터가 있을 때만)
    if (category) {
      values.push(category);
      conditions.push(`main_category = $${values.length}`);
    }

    // 도시(시/도) 필터
    if (city) {
      values.push(`%${city}%`);
      conditions.push(`address LIKE $${values.length}`);
    }
    // 구/군 필터
    if (district) {
      values.push(`%${district}%`);
      conditions.push(`address LIKE $${values.length}`);
    }
    // 동/읍/면 필터
    if (neighborhood) {
      values.push(`%${neighborhood}%`);
      conditions.push(`address LIKE $${values.length}`);
    }

    // where절이 하나도 없으면 빈 문자열
    const whereClause = conditions.length
      ? `WHERE ${conditions.join(' AND ')}`
      : '';

    const query = `
      SELECT *
      FROM place_info
      ${whereClause}
      ORDER BY id
    `;
    const { rows } = await pool.query(query, values);
    res.json(rows);
  } catch (err) {
    console.error('getFilteredPlaces error:', err);
    res.status(500).json({ error: 'Failed to load places' });
  }
}
const getWeeklyRanking = async (req, res) => {
  // 쿼리 파라미터에서 limit, category 가져오기
  const limit = parseInt(req.query.limit, 10) || 10;
  const category = req.query.category; // 예: '먹기', '카페', '장소', '놀거리', 또는 undefined

  try {
    // CTE: 지난 7일간 조회수를 집계한 서브쿼리
    // (place_views 테이블이 있다고 가정)
    // category가 있으면 WHERE 절에 main_category = $2 를 추가
    let sql;
    let values;
    if (category) {
      sql = `
      SELECT
        p.id,
        p.place_name,
        p.images,
        COALESCE(w.weekly_views, 0) AS weekly_views,
        p.main_category,
        p.address
      FROM place_info p
      LEFT JOIN (
        SELECT place_id, COUNT(*) AS weekly_views
        FROM place_views
        WHERE viewed_at >= NOW() - INTERVAL '7 days'
        GROUP BY place_id
      ) w
      ON p.id = w.place_id
      WHERE p.main_category = $2
      ORDER BY w.weekly_views DESC NULLS LAST, p.id DESC
      LIMIT $1;
      `;
      values = [limit, category];
    } else {
      sql = `
      SELECT
        p.id,
        p.place_name,
        p.images,
        COALESCE(w.weekly_views, 0) AS weekly_views,
        p.main_category,
        p.address
      FROM place_info p
      LEFT JOIN (
        SELECT place_id, COUNT(*) AS weekly_views
        FROM place_views
        WHERE viewed_at >= NOW() - INTERVAL '7 days'
        GROUP BY place_id
      ) w
      ON p.id = w.place_id
      ORDER BY w.weekly_views DESC NULLS LAST, p.id DESC
      LIMIT $1;
      `;
      values = [limit];
    }

    const result = await pool.query(sql, values);
    // places: Array of { id, place_name, images, weekly_views, main_category, address }
    res.status(200).json({ places: result.rows });
  } catch (error) {
    console.error("Error fetching weekly ranking:", error);
    res.status(500).json({ error: "Server error" });
  }
};
module.exports = {
  createPlace,
  getPlaces,
  getPlaceById,
  getFilteredPlaces,
  getWeeklyRanking,
  updatePlace,
  getPlaceByIdAdmin,
};
