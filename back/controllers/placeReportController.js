const pool = require('../config/db');
const chatCtrl = require('./chatRoomsController');

const reportPlace = async (req, res) => {
  const placeId = parseInt(req.params.id, 10);
  const { user_id, category, reason } = req.body;
  if (!user_id || !category || !reason || String(category).trim() === '') {
    return res
      .status(400)
      .json({ error: 'user_id, category and reason required' });
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
SELECT
        pr.id,
        pr.place_id,
        pr.user_id,
        pr.category,
        pr.reason,
        pr.status,
        pr.created_at,
        u.nickname AS reporter_nickname,
        p.place_name      FROM place_reports pr
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
  const { delete_place, message } = req.body;
  const adminId = parseInt(
    req.body.user_id || req.body.admin_id || req.headers['user_id'],
    10
  );  try {
    const { rows } = await pool.query(
      'UPDATE place_reports SET status=$1 WHERE id=$2 RETURNING *',
      ['resolved', reportId]
    );
    if (!rows.length) return res.status(404).json({ error: 'Not found' });
    const report = rows[0];

    if (delete_place === true) {
      await pool.query('DELETE FROM place_info WHERE id=$1', [report.place_id]);
    }
    if (adminId && message) {
        try {
          const { rows: roomRows } = await pool.query(
            `SELECT crm.room_id
               FROM chat_room_members crm
              WHERE crm.user_id IN ($1,$2)
              GROUP BY crm.room_id
             HAVING COUNT(*) = 2
                AND (SELECT COUNT(*) FROM chat_room_members WHERE room_id = crm.room_id) = 2
              LIMIT 1`,
            [adminId, report.user_id]
          );
          let roomId;
          if (roomRows.length) {
            roomId = roomRows[0].room_id;
          } else {
            const roomRes = await pool.query(
              'INSERT INTO chat_rooms(is_group) VALUES(false) RETURNING id'
            );
            roomId = roomRes.rows[0].id;
            await pool.query(
              'INSERT INTO chat_room_members(room_id, user_id) VALUES ($1,$2), ($1,$3)',
              [roomId, adminId, report.user_id]
            );
          }
          const mockReq = {
            params: { roomId },
            body: { sender_id: adminId, type: 'text', content: message },
          };
          const noop = () => ({ json: () => {} });
          await chatCtrl.postMessage(mockReq, { status: noop, json: () => {} });
        } catch (e) {
          console.error('send chat error:', e);
        }
      }
  
      res.json({ report });  } catch (err) {
    console.error('updateReport error:', err);
    res.status(500).json({ error: 'Server error' });
  }
};

module.exports = { reportPlace, listReports, updateReport };