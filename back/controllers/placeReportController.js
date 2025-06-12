const pool = require('../config/db');

const reportPlace = async (req, res) => {
  const placeId = parseInt(req.params.id, 10);
  const { user_id, category, reason } = req.body;
  if (!user_id || !category || !reason) {
    return res.status(400).json({ error: 'user_id, category and reason required' });
  }
  try {
    const { rows } = await pool.query(
      `INSERT INTO place_reports (place_id, user_id, category, reason, status)
       VALUES ($1, $2, $3, $4, 'pending')
       RETURNING *`,
      [placeId, user_id, category, reason]
    );
    res.status(201).json({ report: rows[0] });
  } catch (err) {
    console.error('reportPlace error:', err);
    res.status(500).json({ error: 'Server error' });
  }
};

const listReports = async (_req, res) => {
  try {
    const { rows } = await pool.query(`
      SELECT pr.*, u.nickname AS reporter_nickname, p.place_name
      FROM place_reports pr
      JOIN users u ON u.id = pr.user_id
      JOIN place_info p ON p.id = pr.place_id
      ORDER BY pr.created_at DESC
    `);
    res.json({ reports: rows });
  } catch (err) {
    console.error('listReports error:', err);
    res.status(500).json({ error: 'Server error' });
  }
};

const updateReport = async (req, res) => {
  const reportId = parseInt(req.params.reportId, 10);
  const { status, delete_place } = req.body;
  try {
    const { rows } = await pool.query(
      'UPDATE place_reports SET status=$1 WHERE id=$2 RETURNING *',
      [status, reportId]
    );
    if (delete_place === true && rows.length) {
      await pool.query('DELETE FROM place_info WHERE id=$1', [rows[0].place_id]);
    }
    res.json({ report: rows[0] });
  } catch (err) {
    console.error('updateReport error:', err);
    res.status(500).json({ error: 'Server error' });
  }
};

module.exports = { reportPlace, listReports, updateReport };