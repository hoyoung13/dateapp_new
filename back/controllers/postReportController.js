const pool = require('../config/db');
const chatCtrl = require('./chatRoomsController');

const reportPost = async (req, res) => {
  const postId = parseInt(req.params.id, 10);
  const { user_id, category, reason } = req.body;
  if (!user_id || !category || !reason || String(category).trim() === '') {
    return res.status(400).json({ error: 'user_id, category and reason required' });
  }
  try {
    const { rows } = await pool.query(
      `INSERT INTO post_reports (post_id, user_id, category, reason, status)
       VALUES ($1, $2, $3, $4, 'pending')
       RETURNING *`,
      [postId, user_id, category, reason]
    );
    res.status(201).json({ report: rows[0] });
  } catch (err) {
    console.error('reportPost error:', err);
    res.status(500).json({ error: 'Server error' });
  }
};

const listReports = async (_req, res) => {
  try {
    const { rows } = await pool.query(`
      SELECT
        pr.id,
        pr.post_id,
        pr.user_id,
        pr.category,
        pr.reason,
        pr.status,
        pr.created_at,
        u.nickname AS reporter_nickname,
        p.title
      FROM post_reports pr
      JOIN users u ON u.id = pr.user_id
      JOIN posts p ON p.id = pr.post_id
      WHERE pr.status = 'pending'
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
  const { delete_post, message } = req.body;
  const adminId = parseInt(
    req.body.user_id || req.body.admin_id || req.headers['user_id'],
    10
  );
  try {
    const { rows } = await pool.query(
      'UPDATE post_reports SET status=$1 WHERE id=$2 RETURNING *',
      ['resolved', reportId]
    );
    if (!rows.length) return res.status(404).json({ error: 'Not found' });
    const report = rows[0];

    if (delete_post === true) {
      await pool.query('DELETE FROM posts WHERE id=$1', [report.post_id]);
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

    res.json({ report });
  } catch (err) {
    console.error('updateReport error:', err);
    res.status(500).json({ error: 'Server error' });
  }
};

module.exports = { reportPost, listReports, updateReport };