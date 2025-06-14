const db = require("../config/db");
exports.getPosts = async (req, res) => {
  const { boardId, user_id, search } = req.query;  // ✅ user_id 추가

  console.log("📌 받은 boardId:", boardId);
  console.log("📌 받은 user_id:", user_id); // ✅ user_id 로그 확인

  try {
    let query = `
      SELECT posts.*,
             boards.name AS board_name,
             users.nickname AS nickname,
             COALESCE(pr.reaction, 0) AS user_reaction,
             CASE
               WHEN posts.user_id = $1 THEN TRUE
               ELSE FALSE
             END AS is_owner
      FROM posts
      LEFT JOIN boards ON posts.board_id = boards.id  
      LEFT JOIN users ON posts.user_id = users.id
      LEFT JOIN posts_reactions pr 
        ON posts.id = pr.post_id AND pr.user_id = $1  
    `;

    let params = [user_id || null];
    const conditions = [];
    // 📌 boardId가 있으면 특정 게시판만 조회
    if (boardId) {
      params.push(boardId);
      conditions.push(`posts.board_id = $${params.length}`);

    }

    if (search) {
      params.push(`%${search}%`);
      const idx = params.length;
      conditions.push(`(posts.title ILIKE $${idx} OR posts.content ILIKE $${idx})`);
    }

    if (conditions.length) {
      query += ' WHERE ' + conditions.join(' AND ');
    }

    query += ' ORDER BY posts.created_at DESC;';
    console.log("📌 실행할 SQL:", query);
    console.log("📌 SQL 실행 파라미터:", params);

    const { rows } = await db.query(query, params);

    console.log("📌 SQL 실행 결과 개수:", rows.length);
    res.status(200).json(rows);
  } catch (error) {
    console.error("❌ 게시글 조회 오류:", error);
    res.status(500).json({ error: "서버 오류 발생" });
  }
};



// 게시글 작성
exports.createPost = async (req, res) => {
  const { user_id, board_id, title, content } = req.body; // ✅ board_id를 직접 받음

  console.log("📌 받은 요청 데이터:", req.body);

  try {
    // ✅ 게시판 존재 여부 확인
    const boardQuery = `SELECT name FROM boards WHERE id = $1`;
    const boardResult = await db.query(boardQuery, [board_id]);

    if (boardResult.rows.length === 0) {
      console.error("❌ 존재하지 않는 게시판 ID:", board_id);
      return res.status(400).json({ error: "잘못된 게시판 ID입니다." });
    }
    const board_name = boardResult.rows[0].name;
    console.log("✅ 게시판 이름:", board_name);

    // ✅ user_id를 이용해서 닉네임 가져오기
    const userQuery = `SELECT nickname FROM users WHERE id = $1`;
    const userResult = await db.query(userQuery, [user_id]);

    if (userResult.rows.length === 0) {
      console.error("❌ 존재하지 않는 사용자 ID:", user_id);
      return res.status(400).json({ error: "존재하지 않는 사용자입니다." });
    }
    const nickname = userResult.rows[0].nickname;
    console.log("✅ 조회된 닉네임:", nickname);

    // ✅ 게시글 저장 (board_id와 nickname 포함)
    const insertQuery = `
      INSERT INTO posts (user_id, board_id, title, content, nickname)
      VALUES ($1, $2, $3, $4, $5)
    `;
    await db.query(insertQuery, [user_id, board_id, title, content, nickname]);

    console.log("✅ 게시글 저장 완료!");
    res.status(201).json({ message: "게시글 작성 완료" });
  } catch (error) {
    console.error("❌ 게시글 작성 중 오류:", error);
    res.status(500).json({ error: "서버 오류 발생" });
  }
};


// 게시글 수정
exports.updatePost = async (req, res) => {
    const { postId } = req.params;
    const { title, content } = req.body;
  
    try {
      const query = `
        UPDATE posts
        SET title = ?, content = ?, updated_at = CURRENT_TIMESTAMP
        WHERE id = ?;
      `;
      const [result] = await db.query(query, [title, content, postId]);
  
      if (result.affectedRows === 0) {
        return res.status(404).json({ error: "게시글을 찾을 수 없음" });
      }
  
      res.json({ message: "게시글 수정 완료" });
    } catch (error) {
      console.error("❌ Error updating post:", error);
      res.status(500).json({ error: "서버 오류 발생" });
    }
  };
// 게시글 삭제
// 게시글 삭제 (사용자 본인 확인 추가)
exports.deletePost = async (req, res) => {
  const { postId } = req.params;
  const { user_id } = req.body; // ✅ 요청에서 user_id도 받아오기

  if (!user_id) {
    return res.status(400).json({ error: "유효한 사용자 ID가 필요합니다." });
  }

  try {
    // ✅ 게시글이 존재하는지 확인하고, 해당 사용자가 작성한 것인지 검증
    const checkQuery = `SELECT user_id FROM posts WHERE id = $1`;
    const checkResult = await db.query(checkQuery, [postId]);

    if (checkResult.rows.length === 0) {
      return res.status(404).json({ error: "게시글을 찾을 수 없습니다." });
    }

    const postOwnerId = checkResult.rows[0].user_id;

    if (postOwnerId !== user_id) {
      return res.status(403).json({ error: "삭제할 권한이 없습니다." });
    }

    // ✅ 본인 게시글이면 삭제 실행
    const deleteQuery = `DELETE FROM posts WHERE id = $1`;
    await db.query(deleteQuery, [postId]);

    res.json({ message: "✅ 게시글 삭제 완료!" });
  } catch (error) {
    console.error("❌ 게시글 삭제 오류:", error);
    res.status(500).json({ error: "서버 오류 발생" });
  }
};

// ✅ 좋아요/싫어요 기능 업데이트
exports.updateReaction = async (req, res) => {
  const { postId } = req.params;
  const { user_id, reaction } = req.body;

  console.log("📌 받은 요청 데이터:", req.body);

  if (![1, -1].includes(reaction)) {
    return res.status(400).json({ error: "잘못된 반응 값입니다." });
  }

  try {
    // ✅ 현재 유저의 반응 가져오기
    const existingQuery = `SELECT reaction FROM posts_reactions WHERE post_id = $1 AND user_id = $2`;
    const existingResult = await db.query(existingQuery, [postId, user_id]);

    if (existingResult.rows.length > 0) {
      const existingReaction = existingResult.rows[0].reaction;

      if (existingReaction === reaction) {
        console.log("✅ 이미 같은 반응 있음 → 삭제 처리 (좋아요 취소 또는 싫어요 취소)");
        
        // ✅ 기존 반응 삭제
        await db.query(`DELETE FROM posts_reactions WHERE post_id = $1 AND user_id = $2`, [postId, user_id]);

        // ✅ 좋아요/싫어요 개수 감소
        if (reaction === 1) {
          await db.query(`UPDATE posts SET likes = likes - 1 WHERE id = $1 RETURNING likes`, [postId]);
        } else if (reaction === -1) {
          await db.query(`UPDATE posts SET dislikes = dislikes - 1 WHERE id = $1 RETURNING dislikes`, [postId]);
        }

        return res.status(200).json({ message: "반응 취소됨" });

      } else {
        console.log("✅ 기존 반응과 다름 → 기존 반응 제거 후 새로운 반응 추가");

        // ✅ 기존 반응 삭제
        await db.query(`DELETE FROM posts_reactions WHERE post_id = $1 AND user_id = $2`, [postId, user_id]);

        // ✅ 좋아요/싫어요 개수 조정 (기존 반응 제거)
        if (existingReaction === 1) {
          await db.query(`UPDATE posts SET likes = likes - 1 WHERE id = $1 RETURNING likes`, [postId]);
        } else if (existingReaction === -1) {
          await db.query(`UPDATE posts SET dislikes = dislikes - 1 WHERE id = $1 RETURNING dislikes`, [postId]);
        }

        // ✅ 새로운 반응 추가
        await db.query(`INSERT INTO posts_reactions (post_id, user_id, reaction) VALUES ($1, $2, $3)`, [postId, user_id, reaction]);

        // ✅ 새로운 반응에 따라 좋아요 또는 싫어요 증가
        let updatedLikes, updatedDislikes;
        if (reaction === 1) {
          const result = await db.query(`UPDATE posts SET likes = likes + 1 WHERE id = $1 RETURNING likes`, [postId]);
          updatedLikes = result.rows[0].likes;
        } else if (reaction === -1) {
          const result = await db.query(`UPDATE posts SET dislikes = dislikes + 1 WHERE id = $1 RETURNING dislikes`, [postId]);
          updatedDislikes = result.rows[0].dislikes;
        }

        console.log("✅ 업데이트된 좋아요 수:", updatedLikes);
        console.log("✅ 업데이트된 싫어요 수:", updatedDislikes);

        return res.status(200).json({ message: "반응 변경됨", likes: updatedLikes, dislikes: updatedDislikes });
      }
    } else {
      console.log("✅ 첫 반응 → 삽입 처리");

      // ✅ 새로운 반응 삽입
      await db.query(`INSERT INTO posts_reactions (post_id, user_id, reaction) VALUES ($1, $2, $3)`, [postId, user_id, reaction]);

      // ✅ 좋아요 또는 싫어요 추가
      let updatedLikes, updatedDislikes;
      if (reaction === 1) {
        const result = await db.query(`UPDATE posts SET likes = likes + 1 WHERE id = $1 RETURNING likes`, [postId]);
        updatedLikes = result.rows[0].likes;
      } else if (reaction === -1) {
        const result = await db.query(`UPDATE posts SET dislikes = dislikes + 1 WHERE id = $1 RETURNING dislikes`, [postId]);
        updatedDislikes = result.rows[0].dislikes;
      }

      console.log("✅ 업데이트된 좋아요 수:", updatedLikes);
      console.log("✅ 업데이트된 싫어요 수:", updatedDislikes);

      return res.status(201).json({ message: "반응 추가됨", likes: updatedLikes, dislikes: updatedDislikes });
    }
  } catch (error) {
    console.error("❌ 반응 업데이트 중 오류:", error);
    res.status(500).json({ error: "서버 오류 발생" });
  }
};
// ✅ 게시글 상세 조회 (댓글 포함)
exports.getPostDetails = async (req, res) => {
  const postId = Number(req.params.postId); // ✅ postId를 숫자로 변환
  console.log(`📌 받은 postId: ${postId}`); // ✅ postId 값 확인

  try {
    // 📌 게시글 정보 가져오기
    const postQuery = `SELECT * FROM posts WHERE id = $1`;
    
    // 📌 댓글 가져올 때 nickname 추가
    const commentQuery = `
      SELECT comments.*, users.nickname 
      FROM comments 
      JOIN users ON comments.user_id = users.id 
      WHERE comments.post_id = $1 
      ORDER BY comments.created_at ASC
    `;

    console.log(`📌 실행할 postQuery: ${postQuery}`);
    console.log(`📌 실행할 commentQuery: ${commentQuery}`);

    const postResult = await db.query(postQuery, [postId]);
    const commentResult = await db.query(commentQuery, [postId]);

    console.log(`📌 postResult.rows.length: ${postResult.rows.length}`);

    if (postResult.rows.length === 0) {
      console.log("❌ 게시글이 DB에 없음!");
      return res.status(404).json({ error: "게시글을 찾을 수 없습니다." });
    }

    res.json({ 
      post: postResult.rows[0], 
      comments: commentResult.rows  // ✅ nickname 포함된 댓글 리스트 반환
    });
  } catch (error) {
    console.error("❌ 게시글 상세 조회 오류:", error); // 🔥 여기에서 정확한 오류 확인
    res.status(500).json({ error: "서버 오류 발생", details: error.message });
  }
};

// ✅ 댓글 작성
exports.createComment = async (req, res) => {
  const { postId } = req.params;
  const { user_id, content } = req.body;

  if (!content) {
      return res.status(400).json({ error: "댓글 내용을 입력하세요." });
  }

  try {
      await db.query(`INSERT INTO comments (post_id, user_id, content) VALUES ($1, $2, $3)`, 
                     [postId, user_id, content]);

      res.status(201).json({ message: "댓글 작성 완료" });
  } catch (error) {
      console.error("❌ Error creating comment:", error);
      res.status(500).json({ error: "서버 오류 발생" });
  }
};
