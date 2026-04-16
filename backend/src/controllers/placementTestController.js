const { query } = require('../db/connection');
const { AppError } = require('../middleware/errorHandler');
const { logger } = require('../utils/logger');

class PlacementTestController {
  /**
   * Get available placement tests
   */
  static async getPlacementTests(req, res) {
    try {
      const result = await query(`
        SELECT id, title, description, created_at
        FROM placement_tests
        ORDER BY created_at DESC
      `);

      res.json({
        success: true,
        data: result.rows
      });
    } catch (error) {
      logger.error('Get placement tests error:', error);
      throw new AppError('Failed to fetch placement tests', 500);
    }
  }

  /**
   * Get specific placement test
   */
  static async getPlacementTest(req, res) {
    try {
      const { id } = req.params;
      
      const result = await query(`
        SELECT id, title, description, questions, created_at
        FROM placement_tests
        WHERE id = $1
      `, [id]);

      if (result.rows.length === 0) {
        throw new AppError('Placement test not found', 404);
      }

      res.json({
        success: true,
        data: result.rows[0]
      });
    } catch (error) {
      logger.error('Get placement test error:', error);
      throw error;
    }
  }

  /**
   * Submit placement test answers
   */
  static async submitPlacementTest(req, res) {
    try {
      const { id } = req.params;
      const { answers } = req.body;
      const userId = req.user.id;

      // Get the test
      const testResult = await query(`
        SELECT id, title, questions
        FROM placement_tests
        WHERE id = $1
      `, [id]);

      if (testResult.rows.length === 0) {
        throw new AppError('Placement test not found', 404);
      }

      const test = testResult.rows[0];
      const questions = test.questions;

      // Calculate score
      let score = 0;
      const maxScore = questions.length;

      questions.forEach((question, index) => {
        if (answers[index] !== undefined && answers[index] === question.correct) {
          score++;
        }
      });

      // Determine recommended level
      const percentage = (score / maxScore) * 100;
      let recommendedLevel;
      
      if (percentage >= 80) {
        recommendedLevel = 'advanced';
      } else if (percentage >= 60) {
        recommendedLevel = 'intermediate';
      } else {
        recommendedLevel = 'beginner';
      }

      // Save results
      await query(`
        INSERT INTO placement_test_results (user_id, test_id, score, max_score, recommended_level)
        VALUES ($1, $2, $3, $4, $5)
        ON CONFLICT (user_id, test_id) 
        DO UPDATE SET 
          score = $3,
          max_score = $4,
          recommended_level = $5,
          completed_at = NOW()
      `, [userId, id, score, maxScore, recommendedLevel]);

      res.json({
        success: true,
        data: {
          score,
          maxScore,
          percentage: Math.round(percentage),
          recommendedLevel,
          title: test.title
        }
      });
    } catch (error) {
      logger.error('Submit placement test error:', error);
      throw error;
    }
  }

  /**
   * Get user's placement test results
   */
  static async getUserResults(req, res) {
    try {
      const userId = req.user.id;

      const result = await query(`
        SELECT 
          ptr.id,
          ptr.score,
          ptr.max_score,
          ptr.recommended_level,
          ptr.completed_at,
          pt.title,
          pt.description
        FROM placement_test_results ptr
        JOIN placement_tests pt ON ptr.test_id = pt.id
        WHERE ptr.user_id = $1
        ORDER BY ptr.completed_at DESC
      `, [userId]);

      res.json({
        success: true,
        data: result.rows
      });
    } catch (error) {
      logger.error('Get user results error:', error);
      throw new AppError('Failed to fetch results', 500);
    }
  }

  /**
   * Create new placement test (admin/instructor only)
   */
  static async createPlacementTest(req, res) {
    try {
      const { title, description, questions } = req.body;

      // Validation
      if (!title || !description || !questions || !Array.isArray(questions)) {
        throw new AppError('Title, description, and questions are required', 400);
      }

      if (questions.length < 3) {
        throw new AppError('At least 3 questions are required', 400);
      }

      // Validate questions format
      questions.forEach((q, index) => {
        if (!q.question || !q.options || !Array.isArray(q.options) || q.correct === undefined) {
          throw new AppError(`Invalid question format at index ${index}`, 400);
        }
        if (q.options.length < 2) {
          throw new AppError(`Question at index ${index} must have at least 2 options`, 400);
        }
        if (q.correct < 0 || q.correct >= q.options.length) {
          throw new AppError(`Invalid correct answer for question at index ${index}`, 400);
        }
      });

      const result = await query(`
        INSERT INTO placement_tests (title, description, questions)
        VALUES ($1, $2, $3)
        RETURNING id, title, description, created_at
      `, [title, description, JSON.stringify(questions)]);

      res.status(201).json({
        success: true,
        data: result.rows[0]
      });
    } catch (error) {
      logger.error('Create placement test error:', error);
      throw error;
    }
  }
}

module.exports = PlacementTestController;
