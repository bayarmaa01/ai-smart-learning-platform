const { query } = require('../db/connection');
const { logger } = require('../utils/logger');
const { validationResult } = require('express-validator');

class AttemptController {
  /**
   * POST /api/v1/attempts/start
   * Start a new exam attempt
   */
  static async startAttempt(req, res) {
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

      const { exam_id } = req.body;
      const { id: user_id, role } = req.user;

      if (role !== 'student') {
        return res.status(403).json({
          success: false,
          error: {
            code: 'ACCESS_DENIED',
            message: 'Only students can start exam attempts'
          }
        });
      }

      // Check if exam exists and is accessible
      const examResult = await query(`
        SELECT e.*, c.id as course_id
        FROM exams e
        LEFT JOIN courses c ON e.course_id = c.id
        WHERE e.id = $1
      `, [exam_id]);

      if (examResult.rows.length === 0) {
        return res.status(404).json({
          success: false,
          error: {
            code: 'EXAM_NOT_FOUND',
            message: 'Exam not found'
          }
        });
      }

      const exam = examResult.rows[0];

      // Check if student is enrolled in the course
      const enrollmentCheck = await query(`
        SELECT 1 FROM enrollments 
        WHERE student_id = $1 AND course_id = $2
      `, [user_id, exam.course_id]);

      if (enrollmentCheck.rows.length === 0) {
        return res.status(403).json({
          success: false,
          error: {
            code: 'NOT_ENROLLED',
            message: 'You are not enrolled in this course'
          }
        });
      }

      // Check if exam is in a valid status for starting
      if (!['published', 'ongoing'].includes(exam.status)) {
        return res.status(400).json({
          success: false,
          error: {
            code: 'EXAM_NOT_AVAILABLE',
            message: 'This exam is not currently available'
          }
        });
      }

      // Check if exam is within time window
      const now = new Date();
      if (exam.start_time && now < new Date(exam.start_time)) {
        return res.status(400).json({
          success: false,
          error: {
            code: 'EXAM_NOT_STARTED',
            message: 'This exam has not started yet'
          }
        });
      }

      if (exam.end_time && now > new Date(exam.end_time)) {
        return res.status(400).json({
          success: false,
          error: {
            code: 'EXAM_ENDED',
            message: 'This exam has already ended'
          }
        });
      }

      // Check if student already has an active attempt
      const existingAttempt = await query(`
        SELECT id, status, started_at FROM attempts 
        WHERE exam_id = $1 AND user_id = $2 AND status = 'in_progress'
      `, [exam_id, user_id]);

      if (existingAttempt.rows.length > 0) {
        return res.status(400).json({
          success: false,
          error: {
            code: 'ACTIVE_ATTEMPT_EXISTS',
            message: 'You already have an active attempt for this exam',
            data: {
              attempt_id: existingAttempt.rows[0].id,
              started_at: existingAttempt.rows[0].started_at
            }
          }
        });
      }

      // Check max attempts limit
      const totalAttempts = await query(`
        SELECT COUNT(*) as count FROM attempts 
        WHERE exam_id = $1 AND user_id = $2
      `, [exam_id, user_id]);

      if (parseInt(totalAttempts.rows[0].count) >= exam.max_attempts) {
        return res.status(400).json({
          success: false,
          error: {
            code: 'MAX_ATTEMPTS_REACHED',
            message: 'You have reached the maximum number of attempts for this exam'
          }
        });
      }

      // Create new attempt
      const client = await require('../db/connection').getClient();
      try {
        await client.query('BEGIN');

        const attemptResult = await client.query(`
          INSERT INTO attempts (
            exam_id, user_id, status, ip_address, user_agent
          ) VALUES ($1, $2, 'in_progress', $3, $4)
          RETURNING *
        `, [
          exam_id, 
          user_id, 
          req.ip || req.connection.remoteAddress,
          req.get('User-Agent')
        ]);

        const attempt = attemptResult.rows[0];

        // Get questions for this attempt (shuffle if required)
        let questionsQuery = `
          SELECT id, question_text, question_type, options, points, order_index
          FROM questions
          WHERE exam_id = $1
        `;

        if (exam.shuffle_questions) {
          questionsQuery += ` ORDER BY RANDOM()`;
        } else {
          questionsQuery += ` ORDER BY order_index`;
        }

        const questionsResult = await client.query(questionsQuery, [exam_id]);

        await client.query('COMMIT');

        logger.info(`User ${user_id} started attempt ${attempt.id} for exam ${exam_id}`);

        res.status(201).json({
          success: true,
          data: {
            attempt: {
              id: attempt.id,
              exam_id: attempt.exam_id,
              started_at: attempt.started_at,
              duration_minutes: exam.duration_minutes,
              status: attempt.status
            },
            questions: questionsResult.rows,
            exam: {
              title: exam.title,
              description: exam.description,
              instructions: exam.instructions,
              duration_minutes: exam.duration_minutes
            }
          }
        });
      } catch (error) {
        await client.query('ROLLBACK');
        throw error;
      } finally {
        client.release();
      }
    } catch (error) {
      logger.error('Error starting attempt:', error);
      res.status(500).json({
        success: false,
        error: {
          code: 'INTERNAL_ERROR',
          message: 'Failed to start exam attempt'
        }
      });
    }
  }

  /**
   * POST /api/v1/attempts/submit
   * Submit exam attempt with answers
   */
  static async submitAttempt(req, res) {
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

      const { attempt_id, answers } = req.body;
      const { id: user_id, role } = req.user;

      if (role !== 'student') {
        return res.status(403).json({
          success: false,
          error: {
            code: 'ACCESS_DENIED',
            message: 'Only students can submit exam attempts'
          }
        });
      }

      // Get attempt details
      const attemptResult = await query(`
        SELECT a.*, e.duration_minutes, e.passing_score
        FROM attempts a
        JOIN exams e ON a.exam_id = e.id
        WHERE a.id = $1 AND a.user_id = $2
      `, [attempt_id, user_id]);

      if (attemptResult.rows.length === 0) {
        return res.status(404).json({
          success: false,
          error: {
            code: 'ATTEMPT_NOT_FOUND',
            message: 'Attempt not found'
          }
        });
      }

      const attempt = attemptResult.rows[0];

      if (attempt.status !== 'in_progress') {
        return res.status(400).json({
          success: false,
          error: {
            code: 'ATTEMPT_NOT_ACTIVE',
            message: 'This attempt is not currently active'
          }
        });
      }

      // Check if attempt has expired
      const now = new Date();
      const startTime = new Date(attempt.started_at);
      const endTime = new Date(startTime.getTime() + attempt.duration_minutes * 60000);

      if (now > endTime) {
        await query(`
          UPDATE attempts 
          SET status = 'expired', submitted_at = NOW()
          WHERE id = $1
        `, [attempt_id]);

        return res.status(400).json({
          success: false,
          error: {
            code: 'ATTEMPT_EXPIRED',
            message: 'This attempt has expired'
          }
        });
      }

      // Get questions and calculate score
      const questionsResult = await query(`
        SELECT id, correct_answer, points, question_type
        FROM questions
        WHERE exam_id = $1
      `, [attempt.exam_id]);

      const questions = questionsResult.rows;
      let totalScore = 0;
      let maxScore = 0;
      const detailedResults = [];

      // Calculate score for each question
      questions.forEach(question => {
        maxScore += question.points;
        const userAnswer = answers[question.id];
        let isCorrect = false;

        if (question.question_type === 'multiple_choice') {
          isCorrect = userAnswer === question.correct_answer;
        } else if (question.question_type === 'true_false') {
          isCorrect = userAnswer === question.correct_answer;
        } else if (question.question_type === 'short_answer') {
          // Case-insensitive comparison for short answers
          isCorrect = userAnswer && 
                     userAnswer.toLowerCase().trim() === 
                     question.correct_answer.toLowerCase().trim();
        }

        if (isCorrect) {
          totalScore += question.points;
        }

        detailedResults.push({
          question_id: question.id,
          user_answer: userAnswer,
          correct_answer: question.correct_answer,
          points: question.points,
          is_correct: isCorrect
        });
      });

      const timeTaken = Math.floor((now - startTime) / 60000); // in minutes

      // Update attempt with results
      const client = await require('../db/connection').getClient();
      try {
        await client.query('BEGIN');

        await client.query(`
          UPDATE attempts 
          SET answers = $1, score = $2, max_score = $3, 
              submitted_at = NOW(), status = 'submitted',
              time_taken_minutes = $4
          WHERE id = $5
        `, [
          JSON.stringify(answers),
          totalScore,
          maxScore,
          timeTaken,
          attempt_id
        ]);

        await client.query('COMMIT');

        logger.info(`User ${user_id} submitted attempt ${attempt_id} with score ${totalScore}/${maxScore}`);

        res.json({
          success: true,
          data: {
            attempt_id: attempt_id,
            score: totalScore,
            max_score: maxScore,
            percentage: Math.round((totalScore / maxScore) * 100),
            passed: totalScore >= (attempt.passing_score * maxScore / 100),
            time_taken_minutes: timeTaken,
            submitted_at: now,
            detailed_results: detailedResults
          }
        });
      } catch (error) {
        await client.query('ROLLBACK');
        throw error;
      } finally {
        client.release();
      }
    } catch (error) {
      logger.error('Error submitting attempt:', error);
      res.status(500).json({
        success: false,
        error: {
          code: 'INTERNAL_ERROR',
          message: 'Failed to submit exam attempt'
        }
      });
    }
  }

  /**
   * GET /api/v1/attempts/:id
   * Get attempt details
   */
  static async getAttempt(req, res) {
    try {
      const { id } = req.params;
      const { id: user_id, role } = req.user;

      const result = await query(`
        SELECT a.*, e.title as exam_title, e.duration_minutes,
               e.passing_score, e.show_results,
               u.first_name || ' ' || u.last_name as student_name
        FROM attempts a
        JOIN exams e ON a.exam_id = e.id
        JOIN users u ON a.user_id = u.id
        WHERE a.id = $1
      `, [id]);

      if (result.rows.length === 0) {
        return res.status(404).json({
          success: false,
          error: {
            code: 'ATTEMPT_NOT_FOUND',
            message: 'Attempt not found'
          }
        });
      }

      const attempt = result.rows[0];

      // Check permissions
      if (role === 'student' && attempt.user_id !== user_id) {
        return res.status(403).json({
          success: false,
          error: {
            code: 'ACCESS_DENIED',
            message: 'Access denied to this attempt'
          }
        });
      }

      // For teachers, check if they own the exam
      if (role === 'teacher') {
        const examCheck = await query(`
          SELECT instructor_id FROM exams WHERE id = $1
        `, [attempt.exam_id]);

        if (examCheck.rows[0].instructor_id !== user_id) {
          return res.status(403).json({
            success: false,
            error: {
              code: 'ACCESS_DENIED',
              message: 'Access denied to this attempt'
            }
          });
        }
      }

      // Hide answers if exam doesn't show results and user is student
      if (role === 'student' && !attempt.show_results && attempt.status === 'submitted') {
        delete attempt.answers;
        delete attempt.score;
        delete attempt.detailed_results;
      }

      logger.info(`User ${user_id} retrieved attempt ${id}`);

      res.json({
        success: true,
        data: attempt
      });
    } catch (error) {
      logger.error('Error fetching attempt:', error);
      res.status(500).json({
        success: false,
        error: {
          code: 'INTERNAL_ERROR',
          message: 'Failed to fetch attempt'
        }
      });
    }
  }

  /**
   * GET /api/v1/student/results
   * Get student's exam results
   */
  static async getStudentResults(req, res) {
    try {
      const { id: user_id } = req.user;
      const { exam_id } = req.query;

      let whereClause = 'WHERE a.user_id = $1';
      const params = [user_id];

      if (exam_id) {
        whereClause += ' AND a.exam_id = $2';
        params.push(exam_id);
      }

      const result = await query(`
        SELECT a.id, a.exam_id, a.score, a.max_score, a.status,
               a.started_at, a.submitted_at, a.time_taken_minutes,
               e.title as exam_title, e.passing_score,
               CASE 
                 WHEN a.score IS NOT NULL AND a.max_score > 0 
                 THEN ROUND((a.score::float / a.max_score::float) * 100)
                 ELSE 0 
               END as percentage,
               CASE 
                 WHEN a.score IS NOT NULL AND a.max_score > 0 AND 
                      a.score >= (e.passing_score * a.max_score / 100)
                 THEN true 
                 ELSE false 
               END as passed
        FROM attempts a
        JOIN exams e ON a.exam_id = e.id
        ${whereClause}
        ORDER BY a.submitted_at DESC NULLS LAST, a.started_at DESC
      `, params);

      logger.info(`User ${user_id} retrieved ${result.rows.length} results`);

      res.json({
        success: true,
        data: result.rows,
        count: result.rows.length
      });
    } catch (error) {
      logger.error('Error fetching student results:', error);
      res.status(500).json({
        success: false,
        error: {
          code: 'INTERNAL_ERROR',
          message: 'Failed to fetch student results'
        }
      });
    }
  }

  /**
   * GET /api/v1/teacher/results
   * Get teacher's exam results
   */
  static async getTeacherResults(req, res) {
    try {
      const { id: user_id } = req.user;
      const { exam_id } = req.query;

      let whereClause = 'WHERE e.instructor_id = $1';
      const params = [user_id];

      if (exam_id) {
        whereClause += ' AND a.exam_id = $2';
        params.push(exam_id);
      }

      const result = await query(`
        SELECT a.id, a.exam_id, a.user_id, a.score, a.max_score, a.status,
               a.started_at, a.submitted_at, a.time_taken_minutes,
               e.title as exam_title, e.passing_score,
               u.first_name || ' ' || u.last_name as student_name,
               u.email as student_email,
               CASE 
                 WHEN a.score IS NOT NULL AND a.max_score > 0 
                 THEN ROUND((a.score::float / a.max_score::float) * 100)
                 ELSE 0 
               END as percentage,
               CASE 
                 WHEN a.score IS NOT NULL AND a.max_score > 0 AND 
                      a.score >= (e.passing_score * a.max_score / 100)
                 THEN true 
                 ELSE false 
               END as passed
        FROM attempts a
        JOIN exams e ON a.exam_id = e.id
        JOIN users u ON a.user_id = u.id
        ${whereClause}
        ORDER BY e.title, a.submitted_at DESC NULLS LAST, a.started_at DESC
      `, params);

      logger.info(`Teacher ${user_id} retrieved ${result.rows.length} results`);

      res.json({
        success: true,
        data: result.rows,
        count: result.rows.length
      });
    } catch (error) {
      logger.error('Error fetching teacher results:', error);
      res.status(500).json({
        success: false,
        error: {
          code: 'INTERNAL_ERROR',
          message: 'Failed to fetch teacher results'
        }
      });
    }
  }

  /**
   * GET /api/v1/attempts/:id/warnings
   * Get proctoring warnings for an attempt
   */
  static async getAttemptWarnings(req, res) {
    try {
      const { id } = req.params;
      const { id: user_id, role } = req.user;

      // Check permissions
      const attemptCheck = await query(`
        SELECT a.*, e.instructor_id
        FROM attempts a
        JOIN exams e ON a.exam_id = e.id
        WHERE a.id = $1
      `, [id]);

      if (attemptCheck.rows.length === 0) {
        return res.status(404).json({
          success: false,
          error: {
            code: 'ATTEMPT_NOT_FOUND',
            message: 'Attempt not found'
          }
        });
      }

      const attempt = attemptCheck.rows[0];

      if (role === 'student' && attempt.user_id !== user_id) {
        return res.status(403).json({
          success: false,
          error: {
            code: 'ACCESS_DENIED',
            message: 'Access denied to this attempt'
          }
        });
      }

      if (role === 'teacher' && attempt.instructor_id !== user_id) {
        return res.status(403).json({
          success: false,
          error: {
            code: 'ACCESS_DENIED',
            message: 'Access denied to this attempt'
          }
        });
      }

      const result = await query(`
        SELECT warning_type, severity, details, timestamp, is_acknowledged
        FROM proctoring_warnings
        WHERE attempt_id = $1
        ORDER BY timestamp DESC
      `, [id]);

      logger.info(`User ${user_id} retrieved warnings for attempt ${id}`);

      res.json({
        success: true,
        data: result.rows,
        count: result.rows.length
      });
    } catch (error) {
      logger.error('Error fetching attempt warnings:', error);
      res.status(500).json({
        success: false,
        error: {
          code: 'INTERNAL_ERROR',
          message: 'Failed to fetch attempt warnings'
        }
      });
    }
  }
}

module.exports = AttemptController;
