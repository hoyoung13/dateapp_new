// courseController.js
const pool = require('../config/db');
const express = require('express');
const router = express.Router();
// 코스 정보와 각 일정(장소)을 저장하는 함수
const createCourse = async (req, res) => {
  // 요청 본문에서 필요한 정보를 추출합니다.
  const {
    user_id,
    course_name,
    course_description,
    hashtags,      // 예: ['#데이트', '#주말']
    selected_date, // 예: '2025-03-21'
    with_who,      // 예: ['연인과', '친구와']
    purpose,       // 예: ['데이트', '맛집탐방']
    schedules      // 배열: 각 일정 객체 { placeId, placeName, placeAddress, placeImage }
  } = req.body;

  try {
    // 트랜잭션 시작
    await pool.query('BEGIN');

    // courses 테이블에 코스 정보 저장
    const insertCourseQuery = `
      INSERT INTO courses (user_id, course_name, course_description, hashtags, selected_date, with_who, purpose)
      VALUES ($1, $2, $3, $4, $5, $6, $7)
      RETURNING id;
    `;
    const courseValues = [
      user_id,
      course_name,
      course_description,
      hashtags,
      selected_date,
      with_who,
      purpose
    ];
    const courseResult = await pool.query(insertCourseQuery, courseValues);
    const courseId = courseResult.rows[0].id;

    // 각 일정(장소)을 course_schedules 테이블에 저장
    const insertScheduleQuery = `
      INSERT INTO course_schedules (course_id, schedule_order, place_id, place_name, place_address, place_image)
      VALUES ($1, $2, $3, $4, $5, $6)
      RETURNING id;
    `;

    for (let i = 0; i < schedules.length; i++) {
      const schedule = schedules[i];
      const scheduleValues = [
        courseId,
        i + 1, // 일정 순서 (1부터 시작)
        schedule.placeId,
        schedule.placeName,
        schedule.placeAddress,
        schedule.placeImage
      ];
      await pool.query(insertScheduleQuery, scheduleValues);
    }

    // 모든 쿼리 성공 시 커밋
    await pool.query('COMMIT');
    res.status(201).json({ message: "코스 저장 성공", course_id: courseId });
  } catch (error) {
    // 에러 발생 시 롤백
    await pool.query('ROLLBACK');
    console.error("코스 저장 오류:", error);
    res.status(500).json({ error: "코스 저장에 실패했습니다." });
  }
};
const getCoursesByUser = async (req, res) => {
  try {
    const { user_id } = req.params;

    // 1) courses 테이블에서 해당 user_id의 코스 목록 조회
    const coursesQuery = `
      SELECT *
      FROM courses
      WHERE user_id = $1
      ORDER BY id DESC
    `;
    const coursesResult = await pool.query(coursesQuery, [user_id]);
    const courses = coursesResult.rows;

    // 2) 각 코스마다 schedules 조회하여 합치기
    for (let course of courses) {
      const schedulesQuery = `
        SELECT schedule_order, place_id, place_name, place_address, place_image
        FROM course_schedules
        WHERE course_id = $1
        ORDER BY schedule_order ASC
      `;
      const schedulesResult = await pool.query(schedulesQuery, [course.id]);

      // 코스 객체에 schedules 배열을 추가
      course.schedules = schedulesResult.rows;
    }

    // 응답
    res.status(200).json({ courses });
  } catch (error) {
    console.error("코스 불러오기 오류:", error);
    res.status(500).json({ error: "코스 불러오기 실패" });
  }
};
const deleteCourse = async (req, res) => {
  const courseId = parseInt(req.params.id, 10);
  try {
    // 실제 테이블 이름과 FK 제약조건에 맞추어 삭제 쿼리를 작성하세요.
    const result = await pool.query(
      `DELETE FROM courses WHERE id = $1`,
      [courseId]
    );
    if (result.rowCount === 0) {
      return res.status(404).json({ error: 'Course not found' });
    }
    res.status(200).json({ message: 'Course deleted successfully' });
  } catch (err) {
    console.error('deleteCourse error:', err);
    res.status(500).json({ error: 'Server error' });
  }
}

const getAllCourses = async (req, res) => {
  try {
    // (1) 쿼리 파라미터 읽기
    //    - place: 장소 이름으로 검색 (코스 일정의 place_name)
    //    - with_who: ["연인과","친구와"] 처럼 배열 또는 단일 문자열
    //    - purpose: ["데이트","맛집탐방"] 처럼 배열 또는 단일 문자열
    let { place, with_who, purpose } = req.query;

    // Express에서 query 파라미터가 단일일 때는 string, 복수일 때는 array로 넘어올 수 있음.
    // 배열 형태로 통일
    if (with_who && !Array.isArray(with_who)) {
      with_who = [with_who];
    }
    if (purpose && !Array.isArray(purpose)) {
      purpose = [purpose];
    }

    // (2) courses 테이블 필터 조건을 동적으로 조립
    const courseConditions = [];
    const courseValues = [];  // postgres 쿼리 바인딩용

    // (2-1) “누구와” 필터: courses.with_who 컬럼이 TEXT[] 타입
    //          PostgreSQL overlap 연산자(&&) 사용 → 배열끼리 겹치는지 검사
    if (with_who && with_who.length) {
      courseValues.push(with_who);
      // $1::text[] && with_who
      courseConditions.push(`with_who && $${courseValues.length}::text[]`);
    }

    // (2-2) “무엇을” 필터: courses.purpose 컬럼이 TEXT[] 타입
    if (purpose && purpose.length) {
      courseValues.push(purpose);
      courseConditions.push(`purpose && $${courseValues.length}::text[]`);
    }

    // (3) courses 테이블에서 필터된 코스 먼저 조회 (일정 정보 제외)
    let courseQuery = `
      SELECT
        id,
        user_id,
        course_name,
        course_description,
        hashtags,
        selected_date,
        with_who,
        purpose
      FROM courses
    `;

    if (courseConditions.length) {
      courseQuery += ' WHERE ' + courseConditions.join(' AND ');
    }
    courseQuery += ' ORDER BY created_at DESC';

    const courseResult = await pool.query(courseQuery, courseValues);
    const courses = courseResult.rows;

    // (4) 코스가 하나도 없으면 빈 배열 리턴
    if (courses.length === 0) {
      return res.status(200).json({ courses: [] });
    }

    // (5) 일정(place) 필터를 적용하려면, course_schedules 테이블을 JOIN해서
    //     place_name LIKE '%place%' 조건을 붙여야 함. 
    //     하지만 이미 ①번에서 코스를 가져왔으므로, 
    //     “place” 조건이 있는 경우에는 ID 필터링 후 다시 재조회하는 방식을 쓸 수 있습니다.

    let courseIds = courses.map((c) => c.id);

    if (place && place.trim() !== '') {
      // place 기준으로 course_schedules에서 먼저 해당하는 course_id만 구한다
      const placeValue = `%${place.trim()}%`;
      const placeScheduleQuery = `
        SELECT DISTINCT course_id
        FROM course_schedules
        WHERE place_name ILIKE $1
          AND course_id = ANY($2::int[])
      `;
      // 주의: $2는 위에서 뽑은 courseIds 배열
      const placeScheduleResult = await pool.query(placeScheduleQuery, [placeValue, courseIds]);
      const matched = placeScheduleResult.rows.map((r) => r.course_id);

      // matched에 포함되지 않는 코스는 아예 빼버림
      courseIds = matched;
      if (courseIds.length === 0) {
        return res.status(200).json({ courses: [] });
      }

      // (5-1) courses 배열도 다시 필터링
      const idSet = new Set(courseIds);
      courses = courses.filter((c) => idSet.has(c.id));
    }

    // (6) 최종 courseIds (필터 적용 후) 목록에 대해 schedules(일정) 조회
    //     → course_schedules 테이블에서 course_id = ANY(...) 형태로 한 번에 가져온 뒤,
    //        각 course_id별로 그룹핑
    const scheduleQuery = `
      SELECT
        course_id,
        place_id,
        place_name,
        place_address,
        place_image
        
      FROM course_schedules
      WHERE course_id = ANY($1::int[])
      ORDER BY course_id, schedule_order
    `;//travel_info,max_distance
    
    const scheduleResult = await pool.query(scheduleQuery, [courseIds]);
    const scheduleRows = scheduleResult.rows;

    // (7) course_id별로 일정 정보 묶기
    const schedulesByCourse = {};
    for (const row of scheduleRows) {
      if (!schedulesByCourse[row.course_id]) {
        schedulesByCourse[row.course_id] = [];
      }
      schedulesByCourse[row.course_id].push({
        placeId: row.place_id,
        placeName: row.place_name,
        placeAddress: row.place_address,
        placeImage: row.place_image,
        //travelInfo: row.travel_info,
        //maxDistance: row.max_distance,
      });
    }

    // (8) courses 배열에 일정 정보 붙여서 최종 결과 생성
    const merged = courses.map((c) => ({
      id: c.id,
      userId: c.user_id,
      courseName: c.course_name,
      courseDescription: c.course_description,
      hashtags: c.hashtags,
      selectedDate: c.selected_date,
      withWho: c.with_who,
      purpose: c.purpose,
      schedules: schedulesByCourse[c.id] || [],
    }));

    return res.status(200).json({ courses: merged });
  } catch (error) {
    console.error('getAllCourses error:', error);
    return res.status(500).json({ error: '서버 오류' });
  }
};

module.exports = { createCourse,getCoursesByUser,deleteCourse,getAllCourses };
