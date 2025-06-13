const pool = require('../config/db');
const { addPointHistory } = require('./pointController');

const listItems = async (req, res) => {
  const { category } = req.query;
  try {
    const query = category
      ? 'SELECT * FROM shop_items WHERE category=$1 ORDER BY id'
      : 'SELECT * FROM shop_items ORDER BY id';
    const { rows } = await pool.query(query, category ? [category] : []);
    res.json(rows);
  } catch (err) {
    console.error('listItems error:', err);
    res.status(500).json({ error: 'Server error' });
  }
};

const getItem = async (req, res) => {
  const { id } = req.params;
  try {
    const { rows } = await pool.query('SELECT * FROM shop_items WHERE id=$1', [id]);
    if (!rows.length) return res.status(404).json({ error: 'Not found' });
    res.json(rows[0]);
  } catch (err) {
    console.error('getItem error:', err);
    res.status(500).json({ error: 'Server error' });
  }
};

const createItem = async (req, res) => {
  const { category, name, image_url, price_points } = req.body;
  if (!category || !name || !price_points) {
    return res.status(400).json({ error: 'category, name, price_points required' });
  }
  try {
    const { rows } = await pool.query(
      'INSERT INTO shop_items(category,name,image_url,price_points) VALUES($1,$2,$3,$4) RETURNING *',
      [category, name, image_url, price_points]
    );
    res.status(201).json(rows[0]);
  } catch (err) {
    console.error('createItem error:', err);
    res.status(500).json({ error: 'Server error' });
  }
};

const updateItem = async (req, res) => {
  const { id } = req.params;
  const { category, name, image_url, price_points } = req.body;
  try {
    const { rows } = await pool.query(
      'UPDATE shop_items SET category=$1,name=$2,image_url=$3,price_points=$4 WHERE id=$5 RETURNING *',
      [category, name, image_url, price_points, id]
    );
    if (!rows.length) return res.status(404).json({ error: 'Not found' });
    res.json(rows[0]);
  } catch (err) {
    console.error('updateItem error:', err);
    res.status(500).json({ error: 'Server error' });
  }
};

const deleteItem = async (req, res) => {
  const { id } = req.params;
  try {
    const { rowCount } = await pool.query('DELETE FROM shop_items WHERE id=$1', [id]);
    if (!rowCount) return res.status(404).json({ error: 'Not found' });
    res.json({ message: 'deleted' });
  } catch (err) {
    console.error('deleteItem error:', err);
    res.status(500).json({ error: 'Server error' });
  }
};

const purchaseItem = async (req, res) => {
  const { user_id, item_id } = req.body;
  if (!user_id || !item_id) {
    return res.status(400).json({ error: 'user_id and item_id required' });
  }
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const itemRes = await client.query('SELECT * FROM shop_items WHERE id=$1', [item_id]);
    if (!itemRes.rows.length) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'Item not found' });
    }
    const item = itemRes.rows[0];
    const userRes = await client.query('SELECT points FROM users WHERE id=$1', [user_id]);
    if (!userRes.rows.length) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'User not found' });
    }
    if ((userRes.rows[0].points || 0) < item.price_points) {
      await client.query('ROLLBACK');
      return res.status(400).json({ error: 'Insufficient points' });
    }
    await client.query('UPDATE users SET points = points - $1 WHERE id=$2', [item.price_points, user_id]);
    const barcode = Math.random().toString(36).substring(2, 10);
    const purchaseRes = await client.query(
      'INSERT INTO shop_purchases(user_id,item_id,barcode) VALUES($1,$2,$3) RETURNING *',
      [user_id, item_id, barcode]
    );
    await addPointHistory(user_id, '아이템 구매', -item.price_points);
    await client.query('COMMIT');
    res.status(201).json(purchaseRes.rows[0]);
  } catch (err) {
    await client.query('ROLLBACK');
    console.error('purchaseItem error:', err);
    res.status(500).json({ error: 'Server error' });
  } finally {
    client.release();
  }
};

const getPurchaseHistory = async (req, res) => {
  const { userId } = req.params;
  try {
    const { rows } = await pool.query(
      `SELECT sp.*, si.name AS item_name, si.image_url
         FROM shop_purchases sp
         JOIN shop_items si ON sp.item_id = si.id
        WHERE sp.user_id=$1
        ORDER BY sp.purchased_at DESC`,
      [userId]
    );
    res.json(rows);
  } catch (err) {
    console.error('getPurchaseHistory error:', err);
    res.status(500).json({ error: 'Server error' });
  }
};

module.exports = {
  listItems,
  getItem,
  createItem,
  updateItem,
  deleteItem,
  purchaseItem,
  getPurchaseHistory,
};