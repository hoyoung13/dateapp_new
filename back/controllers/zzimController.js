const pool = require('../config/db');
const { addPointHistory } = require('./pointController');
const createCollection = async (req, res) => {
  console.log("Received collection data:", req.body);

    try {
      const { user_id, collection_name, description, thumbnail, is_public } = req.body;
  
      const query = `
        INSERT INTO collections (user_id, collection_name, description, thumbnail, is_public)
        VALUES ($1, $2, $3, $4, $5)
        RETURNING *;
      `;
      const values = [user_id, collection_name, description, thumbnail, is_public];
  
      const result = await pool.query(query, values);
  
      res.status(201).json({ message: "Collection created", collection: result.rows[0] });
    } catch (error) {
      console.error("Error creating collection:", error);
      res.status(500).json({ error: "Server error" });
    }
  };
  //찜 가져오는거임
  const getCollectionsByUser = async (req, res) => {
    try {
      const { user_id } = req.params;
      const query = `
        SELECT * FROM collections
        WHERE user_id = $1
        ORDER BY (collection_name = '찜목록') DESC, created_at DESC;
      `;
      const values = [user_id];
      const result = await pool.query(query, values);
      res.status(200).json({ collections: result.rows });
    } catch (error) {
      console.error("Error fetching collections:", error);
      res.status(500).json({ error: "Server error" });
    }
  };
  const getPublicCollections = async (req, res) => {
    try {
      const query = `
        SELECT c.*, u.nickname, u.profile_image
        FROM collections c
        JOIN users u ON c.user_id = u.id
        WHERE c.is_public = true
        ORDER BY c.created_at DESC;
      `;
      const result = await pool.query(query);
      res.status(200).json({ collections: result.rows });
    } catch (error) {
      console.error("Error fetching public collections:", error);
      res.status(500).json({ error: "Server error" });
    }
  };
  //삭제기능
  const deleteCollection = async (req, res) => {
    console.log("DELETE 요청:", req.method, req.url);
    console.log("Params:", req.params);
    try {
      const { collection_id } = req.params; 
      // 컬렉션 삭제 쿼리
      const query = `
        DELETE FROM collections
        WHERE id = $1
        RETURNING *
      `;
      const values = [collection_id];
  
      const result = await pool.query(query, values);
  
      if (result.rowCount === 0) {
        // 해당 id를 가진 컬렉션이 없는 경우
        return res.status(404).json({ error: "컬렉션을 찾을 수 없습니다." });
      }
  
      return res.status(200).json({ message: "컬렉션 삭제 성공", deleted: result.rows[0] });
    } catch (error) {
      console.error("Error deleting collection:", error);
      return res.status(500).json({ error: "서버 오류" });
    }
  };
  const addPlaceToCollection = async (req, res) => {
    try {
      const { collection_id, place_id } = req.body;
      const query = `
        INSERT INTO collection_places (collection_id, place_id)
        VALUES ($1, $2)
        RETURNING *;
      `;
      const values = [collection_id, place_id];
    const result = await pool.query(query, values);

    // 해당 장소를 등록한 사용자에게 포인트 지급
    const { rows } = await pool.query(
      'SELECT user_id FROM place_info WHERE id = $1',
      [place_id]
    );
    if (rows.length) {
      await pool.query(
        'UPDATE users SET points = COALESCE(points, 0) + 10 WHERE id = $1',
        [rows[0].user_id]
      );
      await addPointHistory(rows[0].user_id, '장소 즐겨찾기', 10);

    }

    res.status(201).json({ message: "Place added to collection", data: result.rows[0] });
    } catch (error) {
      console.error("Error adding place to collection:", error);
      res.status(500).json({ error: "Server error" });
    }
  };

  const getPlacesInCollection = async (req, res) => {
    try {
      const { collection_id } = req.params; 
      const query = `
        SELECT 
          p.id, 
          p.place_name, 
          p.address,
          p.main_category, 
          p.images, 
          p.rating, 
          p.hashtags
        FROM collection_places cp
        JOIN place_info p ON cp.place_id = p.id
        WHERE cp.collection_id = $1
        ORDER BY cp.id ASC;
      `;
      const values = [collection_id];
      const result = await pool.query(query, values);
      res.status(200).json({ places: result.rows });
    } catch (error) {
      console.error("Error fetching places in collection:", error);
      res.status(500).json({ error: "Server error" });
    }
  };
  const updateCollection = async (req, res) => {
    try {
      const { collection_id } = req.params;
      const { collection_name, description } = req.body;
      const result = await pool.query(
        `UPDATE collections
           SET collection_name = COALESCE($2, collection_name),
               description    = COALESCE($3, description)
         WHERE id = $1
         RETURNING *;`,
        [collection_id, collection_name, description]
      );
      if (result.rowCount === 0) {
        return res.status(404).json({ error: "컬렉션을 찾을 수 없습니다." });
      }
      return res
        .status(200)
        .json({ message: "Collection updated", collection: result.rows[0] });
    } catch (error) {
      console.error("Error updating collection:", error);
      return res.status(500).json({ error: "Server error" });
    }
  };
  
  const deletePlaceFromCollection = async (req, res) => {
    try {
      const { collection_id, place_id } = req.params;
      const result = await pool.query(
        `DELETE FROM collection_places
         WHERE collection_id = $1 AND place_id = $2
         RETURNING *;`,
        [collection_id, place_id]
      );
      if (result.rowCount === 0) {
        return res.status(404).json({ error: "해당 장소가 없습니다." });
      }
      return res
        .status(200)
        .json({ message: "장소 삭제 성공", deleted: result.rows[0] });
    } catch (error) {
      console.error("Error deleting place from collection:", error);
      return res.status(500).json({ error: "Server error" });
    }
  };
  module.exports = {
    createCollection,
    getCollectionsByUser,
    getPublicCollections,
    deleteCollection,
    updateCollection,
    addPlaceToCollection,
    getPlacesInCollection,
    deletePlaceFromCollection,
  };