const pool = require('../config/db');

async function checkDeleteCourse() {
  try {
    // Start a transaction so inserted rows can be rolled back
    await pool.query('BEGIN');

    // Insert a dummy course
    const courseRes = await pool.query(
      "INSERT INTO courses (user_id, course_name) VALUES ($1, $2) RETURNING id",
      [1, 'temp test course']
    );
    const courseId = courseRes.rows[0].id;

    // Insert one schedule row for this course
    await pool.query(
      "INSERT INTO course_schedules (course_id, schedule_order) VALUES ($1, $2)",
      [courseId, 1]
    );

    // Delete the course
    await pool.query('DELETE FROM courses WHERE id = $1', [courseId]);

    // Verify schedules have been removed
    const verify = await pool.query(
      'SELECT 1 FROM course_schedules WHERE course_id = $1',
      [courseId]
    );

    if (verify.rowCount === 0) {
      console.log('\u2714 schedules deleted with course deletion');
    } else {
      console.error('\u274c schedules still exist after deleting course');
    }

    // Roll back to keep DB clean
    await pool.query('ROLLBACK');
  } catch (err) {
    console.error('checkDeleteCourse failed:', err);
    try { await pool.query('ROLLBACK'); } catch (_) {}
    process.exit(1);
    return;
  }
  process.exit(0);
}

checkDeleteCourse();