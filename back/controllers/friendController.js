const pool = require('../config/db');

const getFriends = async (req, res) => {
  const userId = parseInt(req.params.userId, 10);
  try {
    const result = await pool.query(
      `SELECT 
         f.friend_id        AS id,
         u.nickname         AS nickname,
         u.profile_image    AS profile_image
       FROM friendships f
       JOIN users u
         ON u.id = f.friend_id
       WHERE f.user_id = $1`,
      [userId]
    );
    res.status(200).json({ friends: result.rows });
  } catch (err) {
    console.error("getFriends error:", err);
    res.status(500).json({ error: "서버 오류" });
  }
};
// 2-1) 친구 요청 보내기
const sendFri = async (req, res) => {
  const { requesterId, recipientId } = req.body;

  if (requesterId === recipientId) {
    return res.status(400).json({ error: "자기 자신에게는 요청할 수 없습니다." });
  }

  try {
    // 이미 요청이 있거나 이미 친구인 상태인지 체크
    const exists = await pool.query(
      `SELECT 1 FROM friend_requests 
       WHERE requester_id=$1 AND recipient_id=$2 AND status='pending'
       UNION
       SELECT 1 FROM friendships
       WHERE (user_id=$1 AND friend_id=$2)`,
      [requesterId, recipientId]
    );
    if (exists.rows.length > 0) {
      return res.status(409).json({ error: "이미 요청했거나 친구 관계입니다." });
    }

    // 요청 저장
    await pool.query(
      `INSERT INTO friend_requests(requester_id, recipient_id)
       VALUES($1, $2)`,
      [requesterId, recipientId]
    );

    res.status(201).json({ message: "친구 요청이 전송되었습니다." });
  } catch (err) {
    console.error("sendFriendRequest error:", err);
    res.status(500).json({ error: "서버 오류" });
  }
};

// 2-2) 내게 온 보류 중인 요청 조회
const getfri = async (req, res) => {
  const recipientId = parseInt(req.params.userId, 10);
  try {
    const result = await pool.query(
      `SELECT fr.id, fr.requester_id, u.nickname AS requester_nickname, fr.requested_at
       FROM friend_requests fr
       JOIN users u ON u.id = fr.requester_id
       WHERE fr.recipient_id = $1 AND fr.status = 'pending'
       ORDER BY fr.requested_at DESC`,
      [recipientId]
    );
    res.status(200).json({ requests: result.rows });
  } catch (err) {
    console.error("getPendingRequests error:", err);
    res.status(500).json({ error: "서버 오류" });
  }
};

// 2-3) 요청 수락
const acceptFri = async (req, res) => {
  const requestId = parseInt(req.params.requestId, 10);

  try {
    // 1) 요청 정보 조회
    const { rows } = await pool.query(
      `SELECT requester_id, recipient_id 
       FROM friend_requests 
       WHERE id = $1 AND status = 'pending'`,
      [requestId]
    );
    if (rows.length === 0) {
      return res.status(404).json({ error: "유효한 요청이 없습니다." });
    }
    const { requester_id, recipient_id } = rows[0];

    // 2) 상태 업데이트
    await pool.query(
      `UPDATE friend_requests
         SET status = 'accepted', responded_at = NOW()
       WHERE id = $1`,
      [requestId]
    );

    // 3) friendships에 양방향 추가
    await pool.query(
      `INSERT INTO friendships(user_id, friend_id)
       VALUES($1, $2), ($2, $1)
       ON CONFLICT DO NOTHING`,
      [requester_id, recipient_id]
    );

    res.status(200).json({ message: "친구 요청이 수락되었습니다." });
  } catch (err) {
    console.error("acceptFriendRequest error:", err);
    res.status(500).json({ error: "서버 오류" });
  }
};

// 2-4) 요청 거절
const rejectFri = async (req, res) => {
  const requestId = parseInt(req.params.requestId, 10);

  try {
    const result = await pool.query(
      `UPDATE friend_requests
         SET status = 'rejected', responded_at = NOW()
       WHERE id = $1 AND status = 'pending'`,
      [requestId]
    );
    if (result.rowCount === 0) {
      return res.status(404).json({ error: "유효한 요청이 없습니다." });
    }
    res.status(200).json({ message: "친구 요청이 거절되었습니다." });
  } catch (err) {
    console.error("rejectFriendRequest error:", err);
    res.status(500).json({ error: "서버 오류" });
  }
};

const getUserNickname = async (req, res) => {
  const { nickname } = req.query;
  if (!nickname) {
    return res.status(400).json({ error: 'nickname 쿼리 파라미터가 필요합니다.' });
  }

  try {
    const result = await pool.query(
      `SELECT id, nickname, profile_image 
       FROM users 
       WHERE nickname = $1`,
      [nickname]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ error: '해당 닉네임의 사용자를 찾을 수 없습니다.' });
    }
    // 첫 번째 사용자만 반환 (닉네임 중복 허용 안 한다고 가정)
    return res.status(200).json(result.rows[0]);
  } catch (err) {
    console.error('getUserByNickname error:', err);
    return res.status(500).json({ error: '서버 오류' });
  }
};
const getSentRequests = async (req, res) => {
  const requesterId = parseInt(req.params.userId, 10);
  try {
    const result = await pool.query(
      `SELECT fr.id,
              fr.recipient_id,
              u.nickname AS recipient_nickname,
              fr.requested_at
       FROM friend_requests fr
       JOIN users u
         ON u.id = fr.recipient_id
       WHERE fr.requester_id = $1
         AND fr.status = 'pending'
       ORDER BY fr.requested_at DESC`,
      [requesterId]
    );
    res.status(200).json({ requests: result.rows });
  } catch (err) {
    console.error("getSentRequests error:", err);
    res.status(500).json({ error: "서버 오류" });
  }
};
module.exports = { sendFri, getfri,acceptFri,rejectFri,getUserNickname,getSentRequests,getFriends };

