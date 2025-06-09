const pool = require('../config/db');

// GET /reviews/:placeId
async function getReviewsByPlace(req, res) {
  const { placeId } = req.params;
  try {
    const { rows } = await pool.query(
      `SELECT
         r.id,
         r.place_id,
         r.user_id,
         u.nickname   AS username,
         r.rating,
         r.comment,
         r.hashtags,
         r.images,
         r.created_at
       FROM review r
       JOIN users u ON u.id = r.user_id
       WHERE r.place_id = $1
       ORDER BY r.created_at DESC`,
      [placeId]
    );
    res.json({ reviews: rows });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed to load reviews' });
  }
}

// POST /reviews
async function createReview(req, res) {
  const {
    place_id,
    user_id,
    rating,
    comment,
    hashtags = [], // 배열 형태로 넘어온다고 가정
    images   = []  // 배열 형태로 넘어온다고 가정
  } = req.body;

  try {
    const { rows } = await pool.query(
      `INSERT INTO review
         (place_id, user_id, rating, comment, hashtags, images)
       VALUES
         ($1, $2, $3, $4, $5, $6)
       RETURNING *`,
      [place_id, user_id, rating, comment,  hashtags || [],
      images   || []]
    );
    res.status(201).json({ review: rows[0] });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed to save review' });
  }
}

module.exports = { getReviewsByPlace, createReview };
