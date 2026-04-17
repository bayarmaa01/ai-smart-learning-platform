const express = require('express');
const { verifyToken, authorizeRoles } = require('../middleware/auth');
const { query } = require('../db/connection');
const logger = require('../utils/logger');

const router = express.Router();

// Get all courses
router.get('/', async (req, res) => {
  try {
    const { category, level, search } = req.query;
    
    let whereClause = 'WHERE c.status = $1';
    const params = ['published'];
    let paramIndex = 2;

    if (category) {
      whereClause += ` AND cat.slug = $${paramIndex}`;
      params.push(category);
      paramIndex++;
    }

    if (level) {
      whereClause += ` AND c.level = $${paramIndex}`;
      params.push(level);
      paramIndex++;
    }

    if (search) {
      whereClause += ` AND (c.title ILIKE $${paramIndex} OR c.description ILIKE $${paramIndex})`;
      params.push(`%${search}%`);
      paramIndex++;
    }

    const result = await query(`
      SELECT c.*, u.first_name || ' ' || u.last_name as instructor_name,
             cat.name as category_name
      FROM courses c
      LEFT JOIN users u ON c.instructor_id = u.id
      LEFT JOIN categories cat ON c.category_id = cat.id
      ${whereClause}
      ORDER BY c.created_at DESC
    `, params);

    res.json({
      success: true,
      courses: result.rows
    });
  } catch (error) {
    logger.error('Get courses error:', error);
    res.status(500).json({
      success: false,
      error: {
        code: 'INTERNAL_ERROR',
        message: 'Failed to fetch courses'
      }
    });
  }
});

// Get course by ID
router.get('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    
    const result = await query(`
      SELECT c.*, u.first_name || ' ' || u.last_name as instructor_name,
             u.email as instructor_email, cat.name as category_name
      FROM courses c
      LEFT JOIN users u ON c.instructor_id = u.id
      LEFT JOIN categories cat ON c.category_id = cat.id
      WHERE c.id = $1 AND c.status = 'published'
    `, [id]);

    if (result.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: {
          code: 'COURSE_NOT_FOUND',
          message: 'Course not found'
        }
      });
    }

    res.json({
      success: true,
      course: result.rows[0]
    });
  } catch (error) {
    logger.error('Get course error:', error);
    res.status(500).json({
      success: false,
      error: {
        code: 'INTERNAL_ERROR',
        message: 'Failed to fetch course'
      }
    });
  }
});

// Get course lessons
router.get('/:id/lessons', verifyToken, async (req, res) => {
  try {
    const { id } = req.params;
    
    const result = await query(`
      SELECT * FROM lessons
      WHERE course_id = $1 AND is_published = true
      ORDER BY order_index ASC
    `, [id]);

    res.json({
      success: true,
      lessons: result.rows
    });
  } catch (error) {
    logger.error('Get lessons error:', error);
    res.status(500).json({
      success: false,
      error: {
        code: 'INTERNAL_ERROR',
        message: 'Failed to fetch lessons'
      }
    });
  }
});

// Create course (teacher/admin only)
router.post('/', verifyToken, authorizeRoles('teacher', 'admin'), async (req, res) => {
  try {
    const { title, description, shortDescription, level, price, durationHours, categoryId } = req.body;
    
    const result = await query(`
      INSERT INTO courses (instructor_id, category_id, title, slug, description, short_description, level, price, duration_hours, status)
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, 'draft')
      RETURNING *
    `, [
      req.user.userId,
      categoryId,
      title,
      title.toLowerCase().replace(/\s+/g, '-'),
      description,
      shortDescription,
      level,
      price || 0,
      durationHours || 0
    ]);

    res.status(201).json({
      success: true,
      course: result.rows[0]
    });
  } catch (error) {
    logger.error('Create course error:', error);
    res.status(500).json({
      success: false,
      error: {
        code: 'INTERNAL_ERROR',
        message: 'Failed to create course'
      }
    });
  }
});

// Update course (teacher/admin only)
router.put('/:id', verifyToken, authorizeRoles('teacher', 'admin'), async (req, res) => {
  try {
    const { id } = req.params;
    const { title, description, shortDescription, level, price, durationHours, status } = req.body;
    
    // Check if user owns the course or is admin
    const courseCheck = await query('SELECT instructor_id FROM courses WHERE id = $1', [id]);
    if (courseCheck.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: {
          code: 'COURSE_NOT_FOUND',
          message: 'Course not found'
        }
      });
    }

    if (courseCheck.rows[0].instructor_id !== req.user.userId && req.userRole !== 'admin') {
      return res.status(403).json({
        success: false,
        error: {
          code: 'FORBIDDEN',
          message: 'You can only edit your own courses'
        }
      });
    }

    const result = await query(`
      UPDATE courses 
      SET title = $2, description = $3, short_description = $4, level = $5, price = $6, duration_hours = $7, status = $8, updated_at = NOW()
      WHERE id = $1
      RETURNING *
    `, [id, title, description, shortDescription, level, price, durationHours, status]);

    res.json({
      success: true,
      course: result.rows[0]
    });
  } catch (error) {
    logger.error('Update course error:', error);
    res.status(500).json({
      success: false,
      error: {
        code: 'INTERNAL_ERROR',
        message: 'Failed to update course'
      }
    });
  }
});

module.exports = router;
