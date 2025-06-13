const pool = require('../config/db');

const addPointHistory = async (userId, action, points) => {
  try {
    await pool.query(
      'INSERT INTO point_history (user_id, action, points) VALUES ($1, $2, $3)',
      [userId, action, points]
    );
  } catch (err) {
    console.error('addPointHistory error:', err);
  }
};

const getPointHistory = async (req, res) => {
  const { userId } = req.params;
  try {
    const { rows } = await pool.query(
      'SELECT * FROM point_history WHERE user_id = $1 ORDER BY created_at DESC',
      [userId]
    );
    res.json(rows);
  } catch (err) {
    console.error('getPointHistory error:', err);
    res.status(500).json({ error: 'Server error' });
  }
};

module.exports = { addPointHistory, getPointHistory };