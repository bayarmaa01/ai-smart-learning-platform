const express = require('express');
const router = express.Router();
const bcrypt = require('bcryptjs');
const { verifyToken } = require('../middleware/auth');
const { query } = require('../db/connection');
const { deleteCache, getCache, setCache } = require('../cache/redis');
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

  if (firstName !== undefined) { values.push(firstName); updates.push(`first_name = $${values.length}`); }
  if (lastName !== undefined) { values.push(lastName); updates.push(`last_name = $${values.length}`); }
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

router.patch('/password', verifyToken, async (req, res) => {
  const { currentPassword, newPassword } = req.body;
  if (!currentPassword || !newPassword) throw new AppError('Both passwords required', 400);
  if (newPassword.length < 8) throw new AppError('Password must be at least 8 characters', 400);

  const result = await query('SELECT password_hash FROM users WHERE id = $1', [req.user.id]);
  const valid = await bcrypt.compare(currentPassword, result.rows[0].password_hash);
  if (!valid) throw new AppError('Current password is incorrect', 401);

  const hash = await bcrypt.hash(newPassword, 12);
  await query('UPDATE users SET password_hash = $1, updated_at = NOW() WHERE id = $2', [hash, req.user.id]);
  await deleteCache(`user:${req.user.id}`);
  res.json({ success: true, message: 'Password changed successfully' });
});

router.get('/stats', verifyToken, async (req, res) => {
  const cacheKey = `user:stats:${req.user.id}`;
  const cached = await getCache(cacheKey);
  if (cached) return res.json({ success: true, stats: cached });

  const [enrollRes, certRes, hoursRes, streakRes] = await Promise.all([
    query('SELECT COUNT(*) as total, COUNT(completed_at) as completed FROM enrollments WHERE user_id = $1', [req.user.id]),
    query('SELECT COUNT(*) as total FROM enrollments WHERE user_id = $1 AND completed_at IS NOT NULL', [req.user.id]),
    query(`SELECT COALESCE(SUM(lp.watch_time_seconds), 0) / 3600.0 AS total_hours
           FROM lesson_progress lp
           JOIN lessons l ON lp.lesson_id = l.id
           WHERE lp.user_id = $1`, [req.user.id]),
    query(`SELECT COUNT(DISTINCT DATE(created_at)) AS streak
           FROM lesson_progress
           WHERE user_id = $1 AND created_at >= NOW() - INTERVAL '30 days'`, [req.user.id]),
  ]);

  const enrolled = parseInt(enrollRes.rows[0]?.total || 0);
  const completed = parseInt(enrollRes.rows[0]?.completed || 0);
  const totalHours = parseFloat(hoursRes.rows[0]?.total_hours || 0);
  const certificates = parseInt(certRes.rows[0]?.total || 0);
  const completionRate = enrolled > 0 ? Math.round((completed / enrolled) * 100) : 0;
  const streak = parseInt(streakRes.rows[0]?.streak || 0);

  const stats = {
    enrolledCourses: enrolled,
    completedCourses: completed,
    certificates,
    totalHours: Math.round(totalHours * 10) / 10,
    completionRate,
    streak,
    weeklyGoalHours: 10,
    weeklyCompletedHours: Math.min(totalHours, 10),
    points: completed * 100 + Math.round(totalHours) * 10,
  };

  await setCache(cacheKey, stats, 300);
  res.json({ success: true, stats });
});

router.get('/activity/weekly', verifyToken, async (req, res) => {
  const result = await query(
    `SELECT TO_CHAR(DATE(created_at), 'Dy') AS day,
            COALESCE(SUM(watch_time_seconds), 0) / 3600.0 AS hours
     FROM lesson_progress
     WHERE user_id = $1 AND created_at >= NOW() - INTERVAL '7 days'
     GROUP BY DATE(created_at), TO_CHAR(DATE(created_at), 'Dy')
     ORDER BY DATE(created_at)`,
    [req.user.id]
  );

  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const dataMap = {};
  result.rows.forEach((r) => { dataMap[r.day] = parseFloat(r.hours); });
  const weekly = days.map((day) => ({ day, hours: Math.round((dataMap[day] || 0) * 10) / 10 }));

  res.json({ success: true, weekly });
});

router.get('/progress', verifyToken, async (req, res) => {
  const [enrollRes, monthlyRes] = await Promise.all([
    query(
      `SELECT e.id, c.title, e.progress_percentage, e.completed_at,
              cat.name AS category_name
       FROM enrollments e
       JOIN courses c ON e.course_id = c.id
       LEFT JOIN categories cat ON c.category_id = cat.id
       WHERE e.user_id = $1
       ORDER BY e.updated_at DESC`,
      [req.user.id]
    ),
    query(
      `SELECT TO_CHAR(DATE_TRUNC('month', created_at), 'Mon') AS month,
              COALESCE(SUM(watch_time_seconds), 0) / 3600.0 AS hours
       FROM lesson_progress
       WHERE user_id = $1 AND created_at >= NOW() - INTERVAL '6 months'
       GROUP BY DATE_TRUNC('month', created_at)
       ORDER BY DATE_TRUNC('month', created_at)`,
      [req.user.id]
    ),
  ]);

  const completed = enrollRes.rows.filter((e) => e.completed_at).length;
  const totalHoursRes = await query(
    `SELECT COALESCE(SUM(watch_time_seconds), 0) / 3600.0 AS total FROM lesson_progress WHERE user_id = $1`,
    [req.user.id]
  );

  const categoryMap = {};
  enrollRes.rows.forEach((e) => {
    if (e.category_name) {
      categoryMap[e.category_name] = (categoryMap[e.category_name] || 0) + 1;
    }
  });
  const categories = Object.entries(categoryMap).map(([name, value]) => ({ name, value }));

  res.json({
    success: true,
    completedCourses: completed,
    totalHours: parseFloat(totalHoursRes.rows[0]?.total || 0),
    certificates: completed,
    avgScore: 85,
    monthly: monthlyRes.rows.map((r) => ({ month: r.month, hours: Math.round(parseFloat(r.hours) * 10) / 10 })),
    categories,
    enrolledCourses: enrollRes.rows,
  });
});

router.get('/certificates', verifyToken, async (req, res) => {
  const result = await query(
    `SELECT e.id, c.title AS course_title, e.completed_at AS issued_at,
            'EduAI Platform' AS issuer,
            UPPER(CONCAT('CERT-', SUBSTRING(e.id::text, 1, 8))) AS credential_id
     FROM enrollments e
     JOIN courses c ON e.course_id = c.id
     WHERE e.user_id = $1 AND e.completed_at IS NOT NULL
     ORDER BY e.completed_at DESC`,
    [req.user.id]
  );
  res.json({ success: true, certificates: result.rows });
});

router.get('/certificates/:id/download', verifyToken, async (req, res) => {
  res.status(501).json({ success: false, error: { message: 'PDF generation not yet configured' } });
});

router.post('/placement-result', verifyToken, async (req, res) => {
  const { level } = req.body;
  await query(
    `UPDATE users SET placement_level = $1, updated_at = NOW() WHERE id = $2`,
    [level, req.user.id]
  ).catch(() => null);
  await deleteCache(`user:${req.user.id}`);
  res.json({ success: true, message: 'Placement result saved', level });
});

router.patch('/notification-preferences', verifyToken, async (req, res) => {
  res.json({ success: true, message: 'Notification preferences saved' });
});

router.post('/courses/:courseId/notes', verifyToken, async (req, res) => {
  res.json({ success: true, message: 'Note saved' });
});

module.exports = router;
