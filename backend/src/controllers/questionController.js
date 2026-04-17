const { query } = require('../db/connection');
const { logger } = require('../utils/logger');
const { validationResult } = require('express-validator');

class QuestionController {
  /**
   * POST /api/v1/questions
   * Create new question (teachers only)
   */
  static async createQuestion(req, res) {
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
            message: 'Only teachers can create questions'
          }
        });
      }

      const {
        exam_id,
        question_text,
        question_type,
        options,
        correct_answer,
        explanation,
        points,
        order_index
      } = req.body;

      // Check if user owns the exam
      const examCheck = await query(`
        SELECT instructor_id FROM exams WHERE id = $1
      `, [exam_id]);

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

      // Validate question type and options
      if (question_type === 'multiple_choice' && (!options || !Array.isArray(options) || options.length < 2)) {
        return res.status(400).json({
          success: false,
          error: {
            code: 'INVALID_OPTIONS',
            message: 'Multiple choice questions must have at least 2 options'
          }
        });
      }

      const result = await query(`
        INSERT INTO questions (
          exam_id, question_text, question_type, options, 
          correct_answer, explanation, points, order_index
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
        RETURNING *
      `, [
        exam_id,
        question_text,
        question_type,
        options ? JSON.stringify(options) : null,
        correct_answer,
        explanation,
        points || 1,
        order_index || 0
      ]);

      logger.info(`User ${userId} created question ${result.rows[0].id} for exam ${exam_id}`);

      res.status(201).json({
        success: true,
        data: result.rows[0]
      });
    } catch (error) {
      logger.error('Error creating question:', error);
      res.status(500).json({
        success: false,
        error: {
          code: 'INTERNAL_ERROR',
          message: 'Failed to create question'
        }
      });
    }
  }

  /**
   * PUT /api/v1/questions/:id
   * Update question (teachers only)
   */
  static async updateQuestion(req, res) {
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

      // Get question with exam info
      const questionResult = await query(`
        SELECT q.*, e.instructor_id
        FROM questions q
        JOIN exams e ON q.exam_id = e.id
        WHERE q.id = $1
      `, [id]);

      if (questionResult.rows.length === 0) {
        return res.status(404).json({
          success: false,
          error: {
            code: 'QUESTION_NOT_FOUND',
            message: 'Question not found'
          }
        });
      }

      const question = questionResult.rows[0];

      if (question.instructor_id !== userId && role !== 'admin') {
        return res.status(403).json({
          success: false,
          error: {
            code: 'ACCESS_DENIED',
            message: 'Access denied to this question'
          }
        });
      }

      const updateFields = [];
      const updateValues = [];
      let paramIndex = 1;

      const allowedFields = [
        'question_text', 'question_type', 'options', 'correct_answer',
        'explanation', 'points', 'order_index'
      ];

      allowedFields.forEach(field => {
        if (req.body[field] !== undefined) {
          updateFields.push(`${field} = $${paramIndex}`);
          if (field === 'options') {
            updateValues.push(JSON.stringify(req.body[field]));
          } else {
            updateValues.push(req.body[field]);
          }
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
        UPDATE questions 
        SET ${updateFields.join(', ')}, updated_at = NOW()
        WHERE id = $${paramIndex}
        RETURNING *
      `, updateValues);

      logger.info(`User ${userId} updated question ${id}`);

      res.json({
        success: true,
        data: result.rows[0]
      });
    } catch (error) {
      logger.error('Error updating question:', error);
      res.status(500).json({
        success: false,
        error: {
          code: 'INTERNAL_ERROR',
          message: 'Failed to update question'
        }
      });
    }
  }

  /**
   * DELETE /api/v1/questions/:id
   * Delete question (teachers only)
   */
  static async deleteQuestion(req, res) {
    try {
      const { id } = req.params;
      const { role, id: userId } = req.user;

      // Get question with exam info
      const questionResult = await query(`
        SELECT q.*, e.instructor_id
        FROM questions q
        JOIN exams e ON q.exam_id = e.id
        WHERE q.id = $1
      `, [id]);

      if (questionResult.rows.length === 0) {
        return res.status(404).json({
          success: false,
          error: {
            code: 'QUESTION_NOT_FOUND',
            message: 'Question not found'
          }
        });
      }

      const question = questionResult.rows[0];

      if (question.instructor_id !== userId && role !== 'admin') {
        return res.status(403).json({
          success: false,
          error: {
            code: 'ACCESS_DENIED',
            message: 'Access denied to this question'
          }
        });
      }

      await query('DELETE FROM questions WHERE id = $1', [id]);

      logger.info(`User ${userId} deleted question ${id}`);

      res.json({
        success: true,
        message: 'Question deleted successfully'
      });
    } catch (error) {
      logger.error('Error deleting question:', error);
      res.status(500).json({
        success: false,
        error: {
          code: 'INTERNAL_ERROR',
          message: 'Failed to delete question'
        }
      });
    }
  }

  /**
   * POST /api/v1/questions/bulk
   * Bulk create questions (teachers only)
   */
  static async bulkCreateQuestions(req, res) {
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
            message: 'Only teachers can create questions'
          }
        });
      }

      const { exam_id, questions } = req.body;

      if (!questions || !Array.isArray(questions) || questions.length === 0) {
        return res.status(400).json({
          success: false,
          error: {
            code: 'INVALID_QUESTIONS',
            message: 'Questions array is required and must not be empty'
          }
        });
      }

      // Check if user owns the exam
      const examCheck = await query(`
        SELECT instructor_id FROM exams WHERE id = $1
      `, [exam_id]);

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

      const client = await require('../db/connection').getClient();
      try {
        await client.query('BEGIN');

        const createdQuestions = [];
        
        for (let i = 0; i < questions.length; i++) {
          const q = questions[i];
          
          const result = await client.query(`
            INSERT INTO questions (
              exam_id, question_text, question_type, options,
              correct_answer, explanation, points, order_index
            ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
            RETURNING *
          `, [
            exam_id,
            q.question_text,
            q.question_type || 'multiple_choice',
            q.options ? JSON.stringify(q.options) : null,
            q.correct_answer,
            q.explanation,
            q.points || 1,
            q.order_index !== undefined ? q.order_index : i
          ]);

          createdQuestions.push(result.rows[0]);
        }

        await client.query('COMMIT');

        logger.info(`User ${userId} bulk created ${createdQuestions.length} questions for exam ${exam_id}`);

        res.status(201).json({
          success: true,
          data: createdQuestions,
          count: createdQuestions.length
        });
      } catch (error) {
        await client.query('ROLLBACK');
        throw error;
      } finally {
        client.release();
      }
    } catch (error) {
      logger.error('Error bulk creating questions:', error);
      res.status(500).json({
        success: false,
        error: {
          code: 'INTERNAL_ERROR',
          message: 'Failed to bulk create questions'
        }
      });
    }
  }
}

module.exports = QuestionController;
