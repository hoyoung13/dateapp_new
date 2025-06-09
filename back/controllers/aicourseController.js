// back/controllers/aicourseController.js

const pool = require('../config/db');
const openai = require('../services/openai');

/**
 * AI 코스 추천 API
 * 클라이언트에서 받은 schedules 배열(각 객체에 main_category, sub_category, max_distance 등 포함)을 
 * 순회하면서, place_info 테이블에서 조건을 만족하는 랜덤 장소를 하나씩 뽑아 반환합니다.
 */
const generateAICourse = async (req, res) => {
  const { user_id, city, district, neighborhood, schedules } = req.body;

  // user_id, city, schedules는 필수
  if (!user_id || !city || !Array.isArray(schedules)) {
    console.warn('generateAICourse: missing field, body=', req.body);
    return res.status(400).json({
      success: false,
      error: 'user_id, city, schedules 는 필수입니다.',
    });
  }

  // schedules 내부에 main_category, sub_category가 반드시 존재해야 한다면 검사
  for (let i = 0; i < schedules.length; i++) {
    const s = schedules[i];
    if (!s.main_category || !s.sub_category) {
      return res.status(400).json({
        success: false,
        error: `schedules[${i}] 에 main_category 혹은 sub_category 가 누락되었습니다.`,
      });
    }
  }

  try {
    const recommendedCourse = [];
    const usedIds = new Set(); // 중복 추천 방지용

    // (1) 일정별로 반복하면서, place_info에서 조건에 맞는 랜덤 장소 한 건씩 뽑기
    for (let i = 0; i < schedules.length; i++) {
      const { main_category, sub_category, max_distance } = schedules[i];

      // SQL 동적 WHERE 절 조립
      // - main_category = $1
      // - sub_category  = $2
      // - address LIKE '%city%' AND (district?) AND (neighborhood?) 
      // - (원한다면 max_distance에 따라 추가 필터 가능)
      const conditions = [];
      const params = [];

      // 1) main_category, sub_category 필터
      params.push(main_category);
      conditions.push(`main_category = $${params.length}`);
      params.push(sub_category);
      conditions.push(`sub_category = $${params.length}`);

      // 2) address 필터 (city, district, neighborhood 각각 LIKE 절)
      //    city (필수) → 주소에 반드시 포함
      params.push(`%${city}%`);
      conditions.push(`address LIKE $${params.length}`);

      if (district) {
        params.push(`%${district}%`);
        conditions.push(`address LIKE $${params.length}`);
      }
      if (neighborhood) {
        params.push(`%${neighborhood}%`);
        conditions.push(`address LIKE $${params.length}`);
      }

      // 3) (선택) max_distance 별 특별 필터 (지오코딩 결과를 통해 반경 계산 등 복잡해질 수 있지만,
      //    이 예시에서는 단순히 카테고리·주소만 필터하고 랜덤 추출)
      //    만약 실제 반경 계산까지 하고 싶다면, latitude/longitude 컬럼을 둔 뒤 ST_DWithin 같은 GIS 함수를 써야 합니다.
      //    여기서는 생략.

      // 최종 SQL: 조건에 맞는 레코드 중에서 하나를 RANDOM()으로 뽑는다
      const sql = `
        SELECT 
          id,
          place_name,
          address,
          images[1] AS place_image
        FROM place_info
        WHERE ${conditions.join(' AND ')}
          ${usedIds.size > 0 ? `AND id NOT IN (${Array.from(usedIds).join(',')})` : ''}
        ORDER BY RANDOM()
        LIMIT 1
      `;

      const { rows } = await pool.query(sql, params);

      if (rows.length > 0) {
        const row = rows[0];
        recommendedCourse.push({
          place_id:      row.id,            // 실제 place_info.id
          place_name:    row.place_name,    // 장소 이름
          place_address: row.address,       // ← 실제 address 컬럼
          place_image:   row.place_image    // images 배열 중 첫 번째
        });
        usedIds.add(row.id);
      } else {
        // 조건에 맞는 장소가 하나도 없으면 null 삽입
        recommendedCourse.push(null);
      }
    }

    // (2) 최종 응답
    return res.status(200).json({
      success: true,
      course:  recommendedCourse, 
    });
  } catch (err) {
    console.error('generateAICourse error:', err);
    return res.status(500).json({ success: false, error: '서버 오류' });
  }
};
const saveAICourse = async (req, res) => {
  const {
    user_id,
    course_name,
    with_who,      // 예: ['연인과', '친구와']
    purpose,       // 예: ['데이트', '맛집탐방']
    schedules      // 배열: 각 일정 객체 { place_id, place_name, place_address, place_image, travel_info, max_distance }
  } = req.body;

  if (!user_id || !course_name || !Array.isArray(with_who) || !Array.isArray(purpose)) {
    return res.status(400).json({ error: "필수 필드 누락" });
  }

  try {
    await pool.query('BEGIN');
    // 1) courses 테이블에 기본 정보 저장
    const insertCourseQuery = `
      INSERT INTO courses 
        (user_id, course_name, with_who, purpose)
      VALUES
        ($1, $2, $3, $4)
      RETURNING id;
    `;
    const courseValues = [
      user_id,
      course_name,       // 1 또는 0
      with_who,           // string 배열 (예: ["연인과","친구와"])
      purpose             // string 배열 (예: ["데이트","맛집탐방"])
    ];
    const courseResult = await pool.query(insertCourseQuery, courseValues);
    const courseId = courseResult.rows[0].id;

    // 2) 각 일정(추천 장소) 정보를 course_schedules에 저장
    const insertScheduleQuery = `
      INSERT INTO course_schedules 
        (course_id, schedule_order, place_id, place_name, place_address, place_image)
      VALUES ($1, $2, $3, $4, $5, $6);
    `;//, travel_info, max_distance
    for (let i = 0; i < schedules.length; i++) {
      const s = schedules[i];
      const values = [
        courseId,
        i + 1,              // 일정 순서
        s.place_id,
        s.place_name,
        s.place_address,
        s.place_image,
        //s.travel_info || null,
        //s.max_distance || null
      ];
      await pool.query(insertScheduleQuery, values);
    }

    await pool.query('COMMIT');
    return res.status(201).json({ success: true, course_id: courseId });
  } catch (err) {
    await pool.query('ROLLBACK');
    console.error('saveAICourse error:', err);
    return res.status(500).json({ success: false, error: '서버 오류' });
  }
};
const recommendPlaces= async (req, res) =>{
  const {
    region, with_who,
    purpose, mood,
    main_category, sub_category
  } = req.body;

  const sql = `
    SELECT id, place_name, description, address, images, rating_avg
    FROM public.place_info
    WHERE address ILIKE $1
      AND main_category = $2
      AND sub_category = $3
      AND with_who && $4
      AND purpose  && $5
      AND mood     && $6
    ORDER BY rating_avg DESC, review_count DESC
    LIMIT 5;
  `;

  try {
    const result = await pool.query(sql, [
      '%' + region + '%',
      main_category,
      sub_category,
      with_who,
      purpose,
      mood
    ]);
    res.json({ places: result.rows });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: '추천 오류 발생' });
  }
}
const aiPlaceRecommend = async (req, res) => {
  console.log('AI 후보:', req.body);

  let { region, userQuery } = req.body;
  const MAX_RETRIES = 3;
  let matched = [];
  let tries = 0;

  while (tries < MAX_RETRIES && matched.length === 0) {
    tries++;
    // (1) AI 후보 5곳 요청
    const prompt = `
"${region}" 에서 "${userQuery}" 관련 유명 맛집 5곳을
JSON 배열 [{ "name": "...", "address": "..." }, ...] 형태로 출력해줘.
    `;
    const aiRaw = await openai.sendChat([
      { role: 'system', content: '당신은 맛집 추천 AI입니다.' },
      { role: 'user',   content: prompt.trim() },
    ]);

    let candidates;
    try {
      candidates = JSON.parse(aiRaw);
    } catch {
      break; // 파싱 오류면 중단
    }
    console.log('AI 후보:', candidates);

    // (2) DB 매칭 (부분 일치: 이름+주소)
    for (const c of candidates) {
      console.log('DB에서 찾는 중:', c.name, c.address);

      const { rows } = await pool.query(
        `SELECT * FROM public.place_info
         WHERE place_name ILIKE $1
           AND address ILIKE $2
         LIMIT 1`,
        [`%${c.name}%`, `%${region}%`]
      );
      if (rows.length > 0) {
        matched = rows;
        break;
      }
    }

    // (3) 매칭 실패 시 키워드 보강
    if (matched.length === 0) {
      userQuery += ' 맛집';
    }
  }

  // (4) 응답
  if (matched.length) {
    res.json({ places: matched });
  } else {
    res.json({
      places: [],
      message: `"${req.body.userQuery}"에 맞는 장소를 찾지 못했습니다.`
    });
  }
}



module.exports = {
  generateAICourse,  saveAICourse,recommendPlaces,aiPlaceRecommend

};
