const pool = require('../config/db');
const chatCtrl = require('./chatRoomsController');

const createInquiry = async (req, res) => {
  const { user_id, title, content } = req.body;
  if (!user_id || !title || !content) {
    return res.status(400).json({ error: 'user_id, title and content required' });
  }
  try {
    const { rows } = await pool.query(
      'INSERT INTO inquiries(user_id, title, content) VALUES($1, $2, $3) RETURNING *',
      [user_id, title, content]
    );
    res.status(201).json({ inquiry: rows[0] });
  } catch (err) {
    console.error('createInquiry error:', err);
    res.status(500).json({ error: 'Server error' });
  }
};

const listInquiries = async (_req, res) => {
  try {
    const { rows } = await pool.query(
      `SELECT i.*, u.nickname AS user_nickname
       FROM inquiries i JOIN users u ON u.id = i.user_id
       ORDER BY i.created_at DESC`
    );
    res.json({ inquiries: rows });
  } catch (err) {
    console.error('listInquiries error:', err);
    res.status(500).json({ error: 'Server error' });
  }
};

const getInquiry = async (req, res) => {
  const id = parseInt(req.params.id, 10);
  try {
    const { rows } = await pool.query(
      `SELECT i.*, u.nickname AS user_nickname
       FROM inquiries i JOIN users u ON u.id = i.user_id
       WHERE i.id=$1`,
      [id]
    );
    if (!rows.length) return res.status(404).json({ error: 'Not found' });
    res.json({ inquiry: rows[0] });
  } catch (err) {
    console.error('getInquiry error:', err);
    res.status(500).json({ error: 'Server error' });
  }
};

const answerInquiry = async (req, res) => {
  const id = parseInt(req.params.id, 10);
  const { answer } = req.body;
  const answerer_id =
    req.body.answerer_id || (req.user && (req.user.id || req.user.userId));
  if (!answer) {
    return res.status(400).json({ error: 'answer required' });
  }
  if (!answerer_id) {
    return res.status(400).json({ error: 'answerer_id required' });
  }
  try {
    const { rows } = await pool.query(
      `UPDATE inquiries
         SET answer=$1, answerer_id=$2, answered_at=NOW(), status='answered'
       WHERE id=$3 RETURNING *`,
      [answer, answerer_id, id]
    );
    if (!rows.length) return res.status(404).json({ error: 'Not found' });
    const inquiry = rows[0];

    try {
      const { rows: roomRows } = await pool.query(
        `SELECT crm.room_id
           FROM chat_room_members crm
          WHERE crm.user_id IN ($1,$2)
          GROUP BY crm.room_id
         HAVING COUNT(*) = 2
            AND (SELECT COUNT(*) FROM chat_room_members WHERE room_id = crm.room_id) = 2
          LIMIT 1`,
        [answerer_id, inquiry.user_id]
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
          [roomId, answerer_id, inquiry.user_id]
        );
      }
      const mockReq = {
        params: { roomId },
        body: { sender_id: answerer_id, type: 'text', content: answer }
      };
      const noop = () => ({ json: () => {} });
      await chatCtrl.postMessage(mockReq, { status: noop, json: () => {} });
    } catch (e) {
      console.error('send chat error:', e);
    }

    res.json({ inquiry });
  } catch (err) {
    console.error('answerInquiry error:', err);
    res.status(500).json({ error: 'Server error' });
  }
};

module.exports = { createInquiry, listInquiries, getInquiry, answerInquiry };