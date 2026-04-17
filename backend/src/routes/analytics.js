const express = require('express');
const { verifyToken, authorizeRoles } = require('../middleware/auth');
const { query } = require('../db/connection');
const logger = require('../utils/logger');

const router = express.Router();

// Get analytics data for admin
router.get('/admin', verifyToken, authorizeRoles('admin'), async (req, res) => {
  try {
    const { timeframe = '30d' } = req.query;
    
    let timeFilter = '';
    if (timeframe === '7d') {
      timeFilter = 'AND created_at >= NOW() - INTERVAL \'7 days\'';
    } else if (timeframe === '30d') {
      timeFilter = 'AND created_at >= NOW() - INTERVAL \'30 days\'';
    } else if (timeframe === '90d') {
      timeFilter = 'AND created_at >= NOW() - INTERVAL \'90 days\'';
    }

    const result = await query(`
      SELECT 
        (SELECT COUNT(*) FROM users WHERE is_active = true) AS active_users,
        (SELECT COUNT(*) FROM users ${timeFilter}) AS new_users,
        (SELECT COUNT(*) FROM courses WHERE status = 'published') AS total_courses,
        (SELECT COUNT(*) FROM enrollments ${timeFilter}) AS new_enrollments,
        (SELECT COALESCE(SUM(c.price), 0) FROM courses c 
         JOIN enrollments e ON c.id = e.course_id 
         WHERE c.is_free = false ${timeFilter}) AS revenue,
        (SELECT COUNT(DISTINCT student_id) FROM enrollments ${timeFilter}) AS active_students
    `);

    const analytics = {
      activeUsers: parseInt(result.rows[0].active_users) || 0,
      newUsers: parseInt(result.rows[0].new_users) || 0,
      totalCourses: parseInt(result.rows[0].total_courses) || 0,
      newEnrollments: parseInt(result.rows[0].new_enrollments) || 0,
      revenue: parseFloat(result.rows[0].revenue) || 0,
      activeStudents: parseInt(result.rows[0].active_students) || 0
    };

    res.json({
      success: true,
      analytics
    });
  } catch (error) {
    logger.error('Get admin analytics error:', error);
    res.status(500).json({
      success: false,
      error: {
        code: 'INTERNAL_ERROR',
        message: 'Failed to fetch analytics'
      }
    });
  }
});

// Get analytics data for teacher
router.get('/teacher', verifyToken, authorizeRoles('teacher', 'admin'), async (req, res) => {
  try {
    const instructorId = req.user.userId;
    const { timeframe = '30d' } = req.query;
    
    let timeFilter = '';
    if (timeframe === '7d') {
      timeFilter = 'AND e.enrolled_at >= NOW() - INTERVAL \'7 days\'';
    } else if (timeframe === '30d') {
      timeFilter = 'AND e.enrolled_at >= NOW() - INTERVAL \'30 days\'';
    } else if (timeframe === '90d') {
      timeFilter = 'AND e.enrolled_at >= NOW() - INTERVAL \'90 days\'';
    }

    const result = await query(`
      SELECT 
        (SELECT COUNT(*) FROM courses WHERE instructor_id = $1 AND status = 'published') AS total_courses,
        (SELECT COUNT(DISTINCT e.student_id) FROM enrollments e 
         JOIN courses c ON e.course_id = c.id 
         WHERE c.instructor_id = $1) AS total_students,
        (SELECT COUNT(*) FROM enrollments e 
         JOIN courses c ON e.course_id = c.id 
         WHERE c.instructor_id = $1 ${timeFilter}) AS new_enrollments,
        (SELECT COALESCE(SUM(c.price), 0) FROM courses c 
         JOIN enrollments e ON c.id = e.course_id 
         WHERE c.instructor_id = $1 AND c.is_free = false ${timeFilter}) AS revenue,
        (SELECT COALESCE(AVG(c.rating_average), 0) FROM courses c 
         WHERE c.instructor_id = $1 AND c.rating_count > 0) AS avg_rating
    `, [instructorId]);

    const analytics = {
      totalCourses: parseInt(result.rows[0].total_courses) || 0,
      totalStudents: parseInt(result.rows[0].total_students) || 0,
      newEnrollments: parseInt(result.rows[0].new_enrollments) || 0,
      revenue: parseFloat(result.rows[0].revenue) || 0,
      avgRating: parseFloat(result.rows[0].avg_rating) || 0
    };

    res.json({
      success: true,
      analytics
    });
  } catch (error) {
    logger.error('Get teacher analytics error:', error);
    res.status(500).json({
      success: false,
      error: {
        code: 'INTERNAL_ERROR',
        message: 'Failed to fetch analytics'
      }
    });
  }
});

// Get course enrollment analytics
router.get('/courses', verifyToken, authorizeRoles('admin', 'teacher'), async (req, res) => {
  try {
    const instructorId = req.user.userId;
    const userRole = req.userRole;
    
    let whereClause = '';
    if (userRole === 'teacher') {
      whereClause = 'WHERE c.instructor_id = $1';
    }

    const result = await query(`
      SELECT 
        c.id,
        c.title,
        c.enrollment_count,
        c.rating_average,
        c.rating_count,
        c.price,
        c.is_free,
        (SELECT COUNT(*) FROM enrollments e WHERE e.course_id = c.id) AS actual_enrollments,
        (SELECT AVG(e.progress_percentage) FROM enrollments e WHERE e.course_id = c.id) AS avg_progress
      FROM courses c
      ${whereClause}
      ORDER BY c.enrollment_count DESC
    `, userRole === 'teacher' ? [instructorId] : []);

    res.json({
      success: true,
      courses: result.rows
    });
  } catch (error) {
    logger.error('Get course analytics error:', error);
    res.status(500).json({
      success: false,
      error: {
        code: 'INTERNAL_ERROR',
        message: 'Failed to fetch course analytics'
      }
    });
  }
});

// Get user activity analytics
router.get('/activity', verifyToken, authorizeRoles('admin'), async (req, res) => {
  try {
    const { timeframe = '30d' } = req.query;
    
    let timeFilter = '';
    if (timeframe === '7d') {
      timeFilter = 'WHERE created_at >= NOW() - INTERVAL \'7 days\'';
    } else if (timeframe === '30d') {
      timeFilter = 'WHERE created_at >= NOW() - INTERVAL \'30 days\'';
    } else if (timeframe === '90d') {
      timeFilter = 'WHERE created_at >= NOW() - INTERVAL \'90 days\'';
    }

    const result = await query(`
      SELECT 
        DATE_TRUNC('day', created_at) as date,
        COUNT(*) as registrations
      FROM users 
      ${timeFilter}
      GROUP BY DATE_TRUNC('day', created_at)
      ORDER BY date ASC
    `);

    res.json({
      success: true,
      activity: result.rows
    });
  } catch (error) {
    logger.error('Get activity analytics error:', error);
    res.status(500).json({
      success: false,
      error: {
        code: 'INTERNAL_ERROR',
        message: 'Failed to fetch activity analytics'
      }
    });
  }
});

module.exports = router;
