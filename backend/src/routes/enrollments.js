const express = require('express');
const { verifyToken } = require('../middleware/auth');
const { query } = require('../db/connection');
const logger = require('../utils/logger');

const router = express.Router();

// Enroll in a course
router.post('/', verifyToken, async (req, res) => {
  try {
    const { courseId } = req.body;
    const userId = req.user.userId;

    // Check if course exists and is published
    const courseCheck = await query('SELECT id, price, is_free FROM courses WHERE id = $1 AND status = $2', [courseId, 'published']);
    if (courseCheck.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: {
          code: 'COURSE_NOT_FOUND',
          message: 'Course not found or not available'
        }
      });
    }

    // Check if already enrolled
    const enrollmentCheck = await query('SELECT id FROM enrollments WHERE student_id = $1 AND course_id = $2', [userId, courseId]);
    if (enrollmentCheck.rows.length > 0) {
      return res.status(409).json({
        success: false,
        error: {
          code: 'ALREADY_ENROLLED',
          message: 'Already enrolled in this course'
        }
      });
    }

    // Create enrollment
    const result = await query(`
      INSERT INTO enrollments (student_id, course_id, enrolled_at)
      VALUES ($1, $2, NOW())
      RETURNING *
    `, [userId, courseId]);

    // Update course enrollment count
    await query('UPDATE courses SET enrollment_count = enrollment_count + 1 WHERE id = $1', [courseId]);

    res.status(201).json({
      success: true,
      enrollment: result.rows[0]
    });
  } catch (error) {
    logger.error('Enrollment error:', error);
    res.status(500).json({
      success: false,
      error: {
        code: 'INTERNAL_ERROR',
        message: 'Failed to enroll in course'
      }
    });
  }
});

// Get user enrollments
router.get('/user/:userId', verifyToken, async (req, res) => {
  try {
    const { userId } = req.params;
    
    // Users can only see their own enrollments
    if (userId !== req.user.userId && req.userRole !== 'admin') {
      return res.status(403).json({
        success: false,
        error: {
          code: 'FORBIDDEN',
          message: 'Access denied'
        }
      });
    }

    const result = await query(`
      SELECT e.*, c.title, c.short_description, c.thumbnail_url, c.level, c.duration_hours,
             u.first_name || ' ' || u.last_name as instructor_name
      FROM enrollments e
      JOIN courses c ON e.course_id = c.id
      JOIN users u ON c.instructor_id = u.id
      WHERE e.student_id = $1
      ORDER BY e.enrolled_at DESC
    `, [userId]);

    res.json({
      success: true,
      enrollments: result.rows
    });
  } catch (error) {
    logger.error('Get enrollments error:', error);
    res.status(500).json({
      success: false,
      error: {
        code: 'INTERNAL_ERROR',
        message: 'Failed to fetch enrollments'
      }
    });
  }
});

// Check enrollment status for a specific course
router.get('/course/:courseId', verifyToken, async (req, res) => {
  try {
    const { courseId } = req.params;
    const userId = req.user.userId;

    const result = await query(`
      SELECT e.*, c.title, c.short_description
      FROM enrollments e
      JOIN courses c ON e.course_id = c.id
      WHERE e.student_id = $1 AND e.course_id = $2
    `, [userId, courseId]);

    if (result.rows.length === 0) {
      return res.json({
        success: true,
        enrolled: false
      });
    }

    res.json({
      success: true,
      enrolled: true,
      enrollment: result.rows[0]
    });
  } catch (error) {
    logger.error('Check enrollment error:', error);
    res.status(500).json({
      success: false,
      error: {
        code: 'INTERNAL_ERROR',
        message: 'Failed to check enrollment status'
      }
    });
  }
});

// Update progress
router.post('/progress', verifyToken, async (req, res) => {
  try {
    const { courseId, lessonId, completed, timeSpent } = req.body;
    const userId = req.user.userId;

    // Verify enrollment
    const enrollmentCheck = await query('SELECT id FROM enrollments WHERE student_id = $1 AND course_id = $2', [userId, courseId]);
    if (enrollmentCheck.rows.length === 0) {
      return res.status(403).json({
        success: false,
        error: {
          code: 'NOT_ENROLLED',
          message: 'Not enrolled in this course'
        }
      });
    }

    // Update or create progress record
    const result = await query(`
      INSERT INTO progress (student_id, course_id, lesson_id, completed, completion_time, time_spent_minutes)
      VALUES ($1, $2, $3, $4, $5, $6)
      ON CONFLICT (student_id, lesson_id)
      DO UPDATE SET
        completed = $4,
        completion_time = $5,
        time_spent_minutes = $6
      RETURNING *
    `, [userId, courseId, lessonId, completed, completed ? 'NOW()' : null, timeSpent || 0]);

    // Calculate overall course progress
    const progressResult = await query(`
      SELECT 
        COUNT(*) as total_lessons,
        COUNT(CASE WHEN completed = true THEN 1 END) as completed_lessons
      FROM lessons l
      LEFT JOIN progress p ON l.id = p.lesson_id AND p.student_id = $1
      WHERE l.course_id = $2 AND l.is_published = true
    `, [userId, courseId]);

    const { total_lessons, completed_lessons } = progressResult.rows[0];
    const progressPercentage = total_lessons > 0 ? (completed_lessons / total_lessons) * 100 : 0;

    // Update enrollment progress
    await query(`
      UPDATE enrollments
      SET progress_percentage = $1
      WHERE student_id = $2 AND course_id = $3
    `, [progressPercentage, userId, courseId]);

    res.json({
      success: true,
      progress: result.rows[0],
      courseProgress: progressPercentage
    });
  } catch (error) {
    logger.error('Update progress error:', error);
    res.status(500).json({
      success: false,
      error: {
        code: 'INTERNAL_ERROR',
        message: 'Failed to update progress'
      }
    });
  }
});

// Get course progress
router.get('/progress/:courseId', verifyToken, async (req, res) => {
  try {
    const { courseId } = req.params;
    const userId = req.user.userId;

    const result = await query(`
      SELECT 
        p.*,
        l.title,
        l.order_index,
        l.duration_minutes
      FROM progress p
      JOIN lessons l ON p.lesson_id = l.id
      WHERE p.student_id = $1 AND p.course_id = $2
      ORDER BY l.order_index
    `, [userId, courseId]);

    res.json({
      success: true,
      progress: result.rows
    });
  } catch (error) {
    logger.error('Get progress error:', error);
    res.status(500).json({
      success: false,
      error: {
        code: 'INTERNAL_ERROR',
        message: 'Failed to fetch progress'
      }
    });
  }
});

module.exports = router;
