const { query } = require('../db/connection');
const { logger } = require('../utils/logger');
const { validationResult } = require('express-validator');

class ExamController {
  /**
   * GET /api/v1/exams
   * Get all exams (filtered by user role)
   */
  static async getExams(req, res) {
    try {
      const { role, id: userId } = req.user;
      let whereClause = '';
      let params = [];

      if (role === 'teacher') {
        whereClause = 'WHERE instructor_id = $1';
        params = [userId];
      } else if (role === 'student') {
        whereClause = 'WHERE status IN ($1, $2, $3)';
        params = ['published', 'ongoing', 'completed'];
      }

      const result = await query(`
        SELECT e.*, c.title as course_title,
               u.first_name || ' ' || u.last_name as instructor_name,
               COUNT(q.id) as question_count
        FROM exams e
        LEFT JOIN courses c ON e.course_id = c.id
        LEFT JOIN users u ON e.instructor_id = u.id
        LEFT JOIN questions q ON e.id = q.exam_id
        ${whereClause}
        GROUP BY e.id, c.title, u.first_name, u.last_name
        ORDER BY e.created_at DESC
      `, params);

      logger.info(`User ${userId} (${role}) retrieved ${result.rows.length} exams`);
      
      res.json({
        success: true,
        data: result.rows,
        count: result.rows.length
      });
    } catch (error) {
      logger.error('Error fetching exams:', error);
      res.status(500).json({
        success: false,
        error: {
          code: 'INTERNAL_ERROR',
          message: 'Failed to fetch exams'
        }
      });
    }
  }

  /**
   * GET /api/v1/exams/:id
   * Get exam by ID
   */
  static async getExamById(req, res) {
    try {
      const { id } = req.params;
      const { role, id: userId } = req.user;

      const result = await query(`
        SELECT e.*, c.title as course_title,
               u.first_name || ' ' || u.last_name as instructor_name,
               COUNT(q.id) as question_count
        FROM exams e
        LEFT JOIN courses c ON e.course_id = c.id
        LEFT JOIN users u ON e.instructor_id = u.id
        LEFT JOIN questions q ON e.id = q.exam_id
        WHERE e.id = $1
        GROUP BY e.id, c.title, u.first_name, u.last_name
      `, [id]);

      if (result.rows.length === 0) {
        return res.status(404).json({
          success: false,
          error: {
            code: 'EXAM_NOT_FOUND',
            message: 'Exam not found'
          }
        });
      }

      const exam = result.rows[0];

      // Check permissions
      if (role === 'teacher' && exam.instructor_id !== userId) {
        return res.status(403).json({
          success: false,
          error: {
            code: 'ACCESS_DENIED',
            message: 'Access denied to this exam'
          }
        });
      }

      // For students, check if they can access this exam
      if (role === 'student') {
        const enrollmentCheck = await query(`
          SELECT 1 FROM enrollments 
          WHERE student_id = $1 AND course_id = $2
        `, [userId, exam.course_id]);

        if (enrollmentCheck.rows.length === 0) {
          return res.status(403).json({
            success: false,
            error: {
              code: 'NOT_ENROLLED',
              message: 'You are not enrolled in this course'
            }
          });
        }
      }

      logger.info(`User ${userId} retrieved exam ${id}`);
      
      res.json({
        success: true,
        data: exam
      });
    } catch (error) {
      logger.error('Error fetching exam:', error);
      res.status(500).json({
        success: false,
        error: {
          code: 'INTERNAL_ERROR',
          message: 'Failed to fetch exam'
        }
      });
    }
  }

  /**
   * POST /api/v1/exams
   * Create new exam (teachers only)
   */
  static async createExam(req, res) {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({
          success: false,
          error: {
            code: 'VALIDATION_ERROR',
            message: 'Validation failed',
            details: errors.array()
          }
        });
      }

      const { role, id: userId } = req.user;
      if (role !== 'teacher' && role !== 'admin') {
        return res.status(403).json({
          success: false,
          error: {
            code: 'INSUFFICIENT_PERMISSIONS',
            message: 'Only teachers can create exams'
          }
        });
      }

      const {
        title,
        description,
        course_id,
        duration_minutes,
        start_time,
        end_time,
        instructions,
        max_attempts,
        passing_score,
        shuffle_questions,
        show_results
      } = req.body;

      const result = await query(`
        INSERT INTO exams (
          title, description, course_id, instructor_id, 
          duration_minutes, start_time, end_time, instructions,
          max_attempts, passing_score, shuffle_questions, show_results
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
        RETURNING *
      `, [
        title, description, course_id, userId,
        duration_minutes, start_time, end_time, instructions,
        max_attempts, passing_score, shuffle_questions, show_results
      ]);

      logger.info(`User ${userId} created exam ${result.rows[0].id}`);
      
      res.status(201).json({
        success: true,
        data: result.rows[0]
      });
    } catch (error) {
      logger.error('Error creating exam:', error);
      res.status(500).json({
        success: false,
        error: {
          code: 'INTERNAL_ERROR',
          message: 'Failed to create exam'
        }
      });
    }
  }

  /**
   * PUT /api/v1/exams/:id
   * Update exam (teachers only)
   */
  static async updateExam(req, res) {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({
          success: false,
          error: {
            code: 'VALIDATION_ERROR',
            message: 'Validation failed',
            details: errors.array()
          }
        });
      }

      const { id } = req.params;
      const { role, id: userId } = req.user;

      // Check if user owns this exam
      const examCheck = await query(`
        SELECT instructor_id FROM exams WHERE id = $1
      `, [id]);

      if (examCheck.rows.length === 0) {
        return res.status(404).json({
          success: false,
          error: {
            code: 'EXAM_NOT_FOUND',
            message: 'Exam not found'
          }
        });
      }

      if (examCheck.rows[0].instructor_id !== userId && role !== 'admin') {
        return res.status(403).json({
          success: false,
          error: {
            code: 'ACCESS_DENIED',
            message: 'Access denied to this exam'
          }
        });
      }

      const updateFields = [];
      const updateValues = [];
      let paramIndex = 1;

      const allowedFields = [
        'title', 'description', 'duration_minutes', 'start_time', 
        'end_time', 'instructions', 'max_attempts', 'passing_score',
        'shuffle_questions', 'show_results', 'status'
      ];

      allowedFields.forEach(field => {
        if (req.body[field] !== undefined) {
          updateFields.push(`${field} = $${paramIndex}`);
          updateValues.push(req.body[field]);
          paramIndex++;
        }
      });

      if (updateFields.length === 0) {
        return res.status(400).json({
          success: false,
          error: {
            code: 'NO_FIELDS_TO_UPDATE',
            message: 'No fields to update'
          }
        });
      }

      updateValues.push(id);

      const result = await query(`
        UPDATE exams 
        SET ${updateFields.join(', ')}, updated_at = NOW()
        WHERE id = $${paramIndex}
        RETURNING *
      `, updateValues);

      logger.info(`User ${userId} updated exam ${id}`);
      
      res.json({
        success: true,
        data: result.rows[0]
      });
    } catch (error) {
      logger.error('Error updating exam:', error);
      res.status(500).json({
        success: false,
        error: {
          code: 'INTERNAL_ERROR',
          message: 'Failed to update exam'
        }
      });
    }
  }

  /**
   * DELETE /api/v1/exams/:id
   * Delete exam (teachers only)
   */
  static async deleteExam(req, res) {
    try {
      const { id } = req.params;
      const { role, id: userId } = req.user;

      // Check if user owns this exam
      const examCheck = await query(`
        SELECT instructor_id FROM exams WHERE id = $1
      `, [id]);

      if (examCheck.rows.length === 0) {
        return res.status(404).json({
          success: false,
          error: {
            code: 'EXAM_NOT_FOUND',
            message: 'Exam not found'
          }
        });
      }

      if (examCheck.rows[0].instructor_id !== userId && role !== 'admin') {
        return res.status(403).json({
          success: false,
          error: {
            code: 'ACCESS_DENIED',
            message: 'Access denied to this exam'
          }
        });
      }

      await query('DELETE FROM exams WHERE id = $1', [id]);

      logger.info(`User ${userId} deleted exam ${id}`);
      
      res.json({
        success: true,
        message: 'Exam deleted successfully'
      });
    } catch (error) {
      logger.error('Error deleting exam:', error);
      res.status(500).json({
        success: false,
        error: {
          code: 'INTERNAL_ERROR',
          message: 'Failed to delete exam'
        }
      });
    }
  }

  /**
   * GET /api/v1/exams/:id/questions
   * Get exam questions
   */
  static async getExamQuestions(req, res) {
    try {
      const { id } = req.params;
      const { role, id: userId } = req.user;

      // Check if user has access to this exam
      const examCheck = await query(`
        SELECT e.*, c.id as course_id
        FROM exams e
        LEFT JOIN courses c ON e.course_id = c.id
        WHERE e.id = $1
      `, [id]);

      if (examCheck.rows.length === 0) {
        return res.status(404).json({
          success: false,
          error: {
            code: 'EXAM_NOT_FOUND',
            message: 'Exam not found'
          }
        });
      }

      const exam = examCheck.rows[0];

      // Check permissions
      if (role === 'teacher' && exam.instructor_id !== userId) {
        return res.status(403).json({
          success: false,
          error: {
            code: 'ACCESS_DENIED',
            message: 'Access denied to this exam'
          }
        });
      }

      // For students, check if they are enrolled and have an active attempt
      if (role === 'student') {
        const enrollmentCheck = await query(`
          SELECT 1 FROM enrollments 
          WHERE student_id = $1 AND course_id = $2
        `, [userId, exam.course_id]);

        if (enrollmentCheck.rows.length === 0) {
          return res.status(403).json({
            success: false,
            error: {
              code: 'NOT_ENROLLED',
              message: 'You are not enrolled in this course'
            }
          });
        }

        // Check if student has an active attempt
        const attemptCheck = await query(`
          SELECT id FROM attempts 
          WHERE exam_id = $1 AND user_id = $2 AND status = 'in_progress'
        `, [id, userId]);

        if (attemptCheck.rows.length === 0) {
          return res.status(403).json({
            success: false,
            error: {
              code: 'NO_ACTIVE_ATTEMPT',
              message: 'You must start an exam attempt first'
            }
          });
        }
      }

      const result = await query(`
        SELECT id, question_text, question_type, options, points, order_index
        FROM questions
        WHERE exam_id = $1
        ORDER BY order_index
      `, [id]);

      logger.info(`User ${userId} retrieved questions for exam ${id}`);
      
      res.json({
        success: true,
        data: result.rows
      });
    } catch (error) {
      logger.error('Error fetching exam questions:', error);
      res.status(500).json({
        success: false,
        error: {
          code: 'INTERNAL_ERROR',
          message: 'Failed to fetch exam questions'
        }
      });
    }
  }
}

module.exports = ExamController;
