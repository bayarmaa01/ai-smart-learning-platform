const express = require('express');
const router = express.Router();
const { verifyToken } = require('../middleware/auth');
const { query } = require('../db/connection');
const { deleteCache } = require('../cache/redis');
const { AppError } = require('../middleware/errorHandler');

router.get('/profile', verifyToken, async (req, res) => {
  const result = await query(
    `SELECT id, email, first_name, last_name, role, avatar_url, bio, language_preference,
            is_email_verified, created_at,
            (SELECT COUNT(*) FROM enrollments WHERE user_id = $1) AS enrolled_courses,
            (SELECT COUNT(*) FROM enrollments WHERE user_id = $1 AND completed_at IS NOT NULL) AS completed_courses
     FROM users WHERE id = $1`,
    [req.user.id]
  );
  res.json({ success: true, user: result.rows[0] });
});

router.patch('/profile', verifyToken, async (req, res) => {
  const { firstName, lastName, bio, languagePreference, avatarUrl } = req.body;
  const updates = [];
  const values = [];

  if (firstName) { values.push(firstName); updates.push(`first_name = $${values.length}`); }
  if (lastName) { values.push(lastName); updates.push(`last_name = $${values.length}`); }
  if (bio !== undefined) { values.push(bio); updates.push(`bio = $${values.length}`); }
  if (languagePreference) { values.push(languagePreference); updates.push(`language_preference = $${values.length}`); }
  if (avatarUrl) { values.push(avatarUrl); updates.push(`avatar_url = $${values.length}`); }

  if (!updates.length) throw new AppError('No fields to update', 400);

  values.push(req.user.id);
  const result = await query(
    `UPDATE users SET ${updates.join(', ')}, updated_at = NOW() WHERE id = $${values.length}
     RETURNING id, email, first_name, last_name, bio, language_preference, avatar_url`,
    values
  );

  await deleteCache(`user:${req.user.id}`);
  res.json({ success: true, user: result.rows[0] });
});

module.exports = router;
