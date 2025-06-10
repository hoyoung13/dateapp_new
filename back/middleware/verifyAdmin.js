const pool = require('../config/db');

const verifyAdmin = async (req, res, next) => {
  try {
    const userId = req.body.user_id || req.params.user_id || req.query.user_id;
    if (!userId) {
      return res.status(401).json({ error: 'User ID required' });
    }
    const { rows } = await pool.query('SELECT is_admin FROM users WHERE id=$1', [userId]);
    if (rows.length && rows[0].is_admin === true) {
      return next();
    }
    return res.status(403).json({ error: 'Admin only' });
  } catch (err) {
    return res.status(500).json({ error: 'Server error' });
  }
};

module.exports = verifyAdmin;
