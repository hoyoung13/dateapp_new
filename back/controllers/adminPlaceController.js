const pool = require('../config/db');
const { addPointHistory } = require('./pointController');

const getPlaceRequests = async (req, res) => {
  try {
    const { rows } = await pool.query('SELECT * FROM place_info WHERE is_approved = false ORDER BY id');
    res.json(rows);
  } catch (err) {
    console.error('getPlaceRequests error:', err);
    res.status(500).json({ error: 'Server error' });
  }
};

const approvePlaceRequest = async (req, res) => {
  const { id } = req.params;
  try {
    await pool.query('UPDATE place_info SET is_approved = true WHERE id = $1', [id]);
     // 승인된 장소의 등록자에게 포인트 지급
     const { rows } = await pool.query('SELECT user_id FROM place_info WHERE id = $1', [id]);
     if (rows.length) {
      await pool.query(
        'UPDATE users SET points = COALESCE(points, 0) + 50 WHERE id = $1',
        [rows[0].user_id]
      );
      await addPointHistory(rows[0].user_id, '장소 등록', 50);
    }
    res.json({ message: 'Place approved' });
  } catch (err) {
    console.error('approvePlaceRequest error:', err);
    res.status(500).json({ error: 'Server error' });
  }
};

const rejectPlaceRequest = async (req, res) => {
  const { id } = req.params;
  try {
    await pool.query('DELETE FROM place_info WHERE id = $1 AND is_approved = false', [id]);
    res.json({ message: 'Place rejected' });
  } catch (err) {
    console.error('rejectPlaceRequest error:', err);
    res.status(500).json({ error: 'Server error' });
  }
};

module.exports = { getPlaceRequests, approvePlaceRequest, rejectPlaceRequest };