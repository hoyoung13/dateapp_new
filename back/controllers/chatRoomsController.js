const pool = require('../config/db');

/**
 * 1:1 채팅방 조회 또는 생성
 */
const startchat = async (req, res) => {
    const userA = parseInt(req.body.userA, 10);
    const userB = parseInt(req.body.userB, 10);
    if (userA === userB) {
      return res.status(400).json({ error: '자기 자신과는 대화를 만들 수 없습니다.' });
    }
  
    try {
      // 기존 방 조회
      const { rows } = await pool.query(`
        SELECT crm.room_id
        FROM chat_room_members crm
        WHERE crm.user_id IN ($1, $2)
        GROUP BY crm.room_id
        HAVING COUNT(*) = 2
          AND (SELECT COUNT(*) FROM chat_room_members WHERE room_id = crm.room_id) = 2
        LIMIT 1
      `, [userA, userB]);
  
      let roomId;
      if (rows.length) {
        roomId = rows[0].room_id;
      } else {
        // 새 방 생성
        const roomRes = await pool.query(`
          INSERT INTO chat_rooms(is_group)
          VALUES(false)
          RETURNING id
        `);
        roomId = roomRes.rows[0].id;
  
        // 멤버 추가
        await pool.query(`
          INSERT INTO chat_room_members(room_id, user_id)
          VALUES($1, $2), ($1, $3)
        `, [roomId, userA, userB]);
      }
  
      res.status(200).json({ roomId });
    } catch (err) {
      console.error('getOrCreate1on1Room error:', err);
      res.status(500).json({ error: '서버 오류' });
    }
  };
  

/**
 * 특정 방의 메시지 조회
 */
const getMessages = async (req, res) => {
  const roomId = parseInt(req.params.roomId, 10);
  try {
    const { rows } = await pool.query(`
      SELECT m.id, m.sender_id, u.nickname AS sender_nickname, m.content, m.sent_at
      FROM messages m
      JOIN users u ON u.id = m.sender_id
      WHERE m.room_id = $1
      ORDER BY m.sent_at
    `, [roomId]);

    res.status(200).json({ messages: rows });
  } catch (err) {
    console.error('getMessages error:', err);
    res.status(500).json({ error: '서버 오류' });
  }
};

/**
 * 방에 새 메시지 삽입
 */
// controllers/chatRoomsController.js

const postMessage = async (req, res) => {
    const roomId     = parseInt(req.params.roomId, 10);
    const { sender_id, type, content, place_id, course_id } = req.body;
  
    if (!sender_id) {
      return res.status(400).json({ error: "sender_id is required" });
    }
  
    let query, params;
  
    if (type === 'text') {
      // 일반 텍스트
      query  = `
        INSERT INTO messages(room_id, sender_id, content)
        VALUES($1, $2, $3)
        RETURNING *`;
      params = [roomId, sender_id, content];
  
    } else if (type === 'place') {
      // 장소 메시지
      query  = `
        INSERT INTO messages(room_id, sender_id, place_id)
        VALUES($1, $2, $3)
        RETURNING *`;
      params = [roomId, sender_id, place_id];
  
    } else if (type === 'course') {
      // 코스 메시지
      query  = `
        INSERT INTO messages(room_id, sender_id, course_id)
        VALUES($1, $2, $3)
        RETURNING *`;
      params = [roomId, sender_id, course_id];
  
    } else {
      return res.status(400).json({ error: "invalid message type" });
    }
  
    try {
      const { rows } = await pool.query(query, params);
      res.status(201).json({ message: rows[0] });
    } catch (err) {
      console.error("postMessage error:", err);
      res.status(500).json({ error: "서버 오류" });
    }
  };
  

/**
 * 사용자가 속한 모든 채팅방 목록 조회
 */
const listUserRooms = async (req, res) => {
  const userId = parseInt(req.params.userId, 10);
  try {
    const { rows } = await pool.query(`
      SELECT cr.id AS room_id,
             cr.is_group,
             MAX(m.sent_at) AS last_message_at,
             -- 1:1 방이라면 상대 닉네임을 가져오기
             CASE WHEN cr.is_group = false
               THEN (SELECT u.nickname
                       FROM chat_room_members crm2
                       JOIN users u ON u.id = crm2.user_id
                      WHERE crm2.room_id = cr.id AND crm2.user_id <> $1
                      LIMIT 1)
               ELSE cr.name
             END AS room_name
      FROM chat_rooms cr
      JOIN chat_room_members crm ON crm.room_id = cr.id
      LEFT JOIN messages m ON m.room_id = cr.id
      WHERE crm.user_id = $1
      GROUP BY cr.id
      ORDER BY last_message_at DESC NULLS LAST
    `, [userId]);

    res.status(200).json({ rooms: rows });
  } catch (err) {
    console.error('listUserRooms error:', err);
    res.status(500).json({ error: '서버 오류' });
  }
};

module.exports = {startchat, getMessages, postMessage, listUserRooms};
