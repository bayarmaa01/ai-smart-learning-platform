const express = require('express');
const { verifyToken, authorizeRoles } = require('../middleware/auth');
const { query } = require('../db/connection');
const logger = require('../utils/logger');

const router = express.Router();

// Get user profile
router.get('/profile', verifyToken, async (req, res) => {
  try {
    const userId = req.user.userId;
    
    const result = await query(`
      SELECT id, email, first_name, last_name, role, avatar_url, bio, language_preference,
             is_email_verified, created_at,
             (SELECT COUNT(*) FROM enrollments WHERE student_id = $1) AS enrolled_courses,
             (SELECT COUNT(*) FROM enrollments WHERE student_id = $1 AND completed_at IS NOT NULL) AS completed_courses,
             (SELECT COALESCE(SUM(time_spent_minutes), 0) FROM progress WHERE student_id = $1) / 60.0 AS total_hours
      FROM users WHERE id = $1
    `, [userId]);

    if (result.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: {
          code: 'USER_NOT_FOUND',
          message: 'User not found'
        }
      });
    }

    const user = result.rows[0];
    const stats = {
      enrolledCourses: parseInt(user.enrolled_courses) || 0,
      completedCourses: parseInt(user.completed_courses) || 0,
      totalHours: parseFloat(user.total_hours) || 0,
      certificates: parseInt(user.completed_courses) || 0
    };

    res.json({
      success: true,
      user: {
        id: user.id,
        email: user.email,
        firstName: user.first_name,
        lastName: user.last_name,
        role: user.role,
        avatarUrl: user.avatar_url,
        bio: user.bio || '',
        languagePreference: user.language_preference || 'en',
        isEmailVerified: user.is_email_verified,
        createdAt: user.created_at
      },
      stats
    });
  } catch (error) {
    logger.error('Get profile error:', error);
    res.status(500).json({
      success: false,
      error: {
        code: 'INTERNAL_ERROR',
        message: 'Failed to fetch profile'
      }
    });
  }
});

// Update user profile
router.put('/profile', verifyToken, async (req, res) => {
  try {
    const userId = req.user.userId;
    const { firstName, lastName, bio, languagePreference, avatarUrl } = req.body;
    
    const result = await query(`
      UPDATE users 
      SET first_name = $2, last_name = $3, bio = $4, language_preference = $5, avatar_url = $6, updated_at = NOW()
      WHERE id = $1
      RETURNING id, email, first_name, last_name, bio, language_preference, avatar_url
    `, [userId, firstName, lastName, bio, languagePreference, avatarUrl]);

    res.json({
      success: true,
      user: result.rows[0]
    });
  } catch (error) {
    logger.error('Update profile error:', error);
    res.status(500).json({
      success: false,
      error: {
        code: 'INTERNAL_ERROR',
        message: 'Failed to update profile'
      }
    });
  }
});

// Get user stats
router.get('/stats', verifyToken, async (req, res) => {
  try {
    const userId = req.user.userId;
    
    const result = await query(`
      SELECT 
        (SELECT COUNT(*) FROM enrollments WHERE student_id = $1) AS enrolled_courses,
        (SELECT COUNT(*) FROM enrollments WHERE student_id = $1 AND completed_at IS NOT NULL) AS completed_courses,
        (SELECT COALESCE(SUM(time_spent_minutes), 0) FROM progress WHERE student_id = $1) / 60.0 AS total_hours,
        (SELECT COUNT(*) FROM enrollments WHERE student_id = $1 AND completed_at IS NOT NULL) AS certificates
    `, [userId]);

    const stats = {
      enrolledCourses: parseInt(result.rows[0].enrolled_courses) || 0,
      completedCourses: parseInt(result.rows[0].completed_courses) || 0,
      totalHours: parseFloat(result.rows[0].total_hours) || 0,
      certificates: parseInt(result.rows[0].certificates) || 0
    };

    res.json({
      success: true,
      stats
    });
  } catch (error) {
    logger.error('Get stats error:', error);
    res.status(500).json({
      success: false,
      error: {
        code: 'INTERNAL_ERROR',
        message: 'Failed to fetch stats'
      }
    });
  }
});

// Admin: Get all users
router.get('/all', verifyToken, authorizeRoles('admin'), async (req, res) => {
  try {
    const result = await query(`
      SELECT id, email, first_name, last_name, role, is_active, is_email_verified, created_at
      FROM users
      ORDER BY created_at DESC
    `);

    res.json({
      success: true,
      users: result.rows
    });
  } catch (error) {
    logger.error('Get all users error:', error);
    res.status(500).json({
      success: false,
      error: {
        code: 'INTERNAL_ERROR',
        message: 'Failed to fetch users'
      }
    });
  }
});

// Teacher: Get students
router.get('/students', verifyToken, authorizeRoles('teacher', 'admin'), async (req, res) => {
  try {
    const result = await query(`
      SELECT DISTINCT u.id, u.email, u.first_name, u.last_name, u.created_at,
             e.enrolled_at, e.progress_percentage
      FROM users u
      JOIN enrollments e ON u.id = e.student_id
      JOIN courses c ON e.course_id = c.id
      WHERE c.instructor_id = $1
      ORDER BY e.enrolled_at DESC
    `, [req.user.userId]);

    res.json({
      success: true,
      students: result.rows
    });
  } catch (error) {
    logger.error('Get students error:', error);
    res.status(500).json({
      success: false,
      error: {
        code: 'INTERNAL_ERROR',
        message: 'Failed to fetch students'
      }
    });
  }
});

// Admin: Get admin stats
router.get('/admin-stats', verifyToken, authorizeRoles('admin'), async (req, res) => {
  try {
    const result = await query(`
      SELECT 
        (SELECT COUNT(*) FROM users) AS total_users,
        (SELECT COUNT(*) FROM courses) AS total_courses,
        (SELECT COUNT(*) FROM enrollments) AS total_enrollments,
        (SELECT COUNT(*) FROM users WHERE is_active = true) AS active_users,
        COALESCE(SUM(c.price), 0) AS total_revenue
      FROM courses c
      JOIN enrollments e ON c.id = e.course_id
      WHERE c.is_free = false
    `);

    const stats = {
      totalUsers: parseInt(result.rows[0].total_users) || 0,
      totalCourses: parseInt(result.rows[0].total_courses) || 0,
      totalRevenue: parseFloat(result.rows[0].total_revenue) || 0,
      activeUsers: parseInt(result.rows[0].active_users) || 0
    };

    res.json({
      success: true,
      stats
    });
  } catch (error) {
    logger.error('Get admin stats error:', error);
    res.status(500).json({
      success: false,
      error: {
        code: 'INTERNAL_ERROR',
        message: 'Failed to fetch admin stats'
      }
    });
  }
});

// Teacher: Get teacher stats
router.get('/teacher-stats', verifyToken, authorizeRoles('teacher', 'admin'), async (req, res) => {
  try {
    const result = await query(`
      SELECT 
        (SELECT COUNT(*) FROM courses WHERE instructor_id = $1) AS total_courses,
        (SELECT COUNT(DISTINCT e.student_id) FROM enrollments e
         JOIN courses c ON e.course_id = c.id WHERE c.instructor_id = $1) AS total_students,
        COALESCE(SUM(c.price), 0) AS total_revenue,
        COALESCE(AVG(c.rating_average), 0) AS avg_rating
      FROM courses c
      WHERE c.instructor_id = $1
    `, [req.user.userId]);

    const stats = {
      totalCourses: parseInt(result.rows[0].total_courses) || 0,
      totalStudents: parseInt(result.rows[0].total_students) || 0,
      totalRevenue: parseFloat(result.rows[0].total_revenue) || 0,
      avgRating: parseFloat(result.rows[0].avg_rating) || 0
    };

    res.json({
      success: true,
      stats
    });
  } catch (error) {
    logger.error('Get teacher stats error:', error);
    res.status(500).json({
      success: false,
      error: {
        code: 'INTERNAL_ERROR',
        message: 'Failed to fetch teacher stats'
      }
    });
  }
});

module.exports = router;
