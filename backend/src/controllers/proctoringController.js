const { query } = require('../db/connection');
const { logger } = require('../utils/logger');
const { validationResult } = require('express-validator');

class ProctoringController {
  /**
   * POST /api/v1/proctoring/warnings
   * Create proctoring warning (from AI service)
   */
  static async createWarning(req, res) {
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

      const { attempt_id, user_id, exam_id, warning_type, severity, details } = req.body;

      // Validate that attempt exists and belongs to user
      const attemptCheck = await query(`
        SELECT a.*, e.instructor_id
        FROM attempts a
        JOIN exams e ON a.exam_id = e.id
        WHERE a.id = $1 AND a.user_id = $2 AND a.exam_id = $3
      `, [attempt_id, user_id, exam_id]);

      if (attemptCheck.rows.length === 0) {
        return res.status(404).json({
          success: false,
          error: {
            code: 'ATTEMPT_NOT_FOUND',
            message: 'Attempt not found or does not belong to user'
          }
        });
      }

      const attempt = attemptCheck.rows[0];

      // Check if attempt is still active
      if (attempt.status !== 'in_progress') {
        return res.status(400).json({
          success: false,
          error: {
            code: 'ATTEMPT_NOT_ACTIVE',
            message: 'Cannot create warnings for inactive attempts'
          }
        });
      }

      // Create warning
      const result = await query(`
        INSERT INTO proctoring_warnings (
          attempt_id, user_id, exam_id, warning_type, severity, details
        ) VALUES ($1, $2, $3, $4, $5, $6)
        RETURNING *
      `, [
        attempt_id,
        user_id,
        exam_id,
        warning_type,
        severity || 'medium',
        details ? JSON.stringify(details) : null
      ]);

      const warning = result.rows[0];

      // Check if this warning should mark the attempt as suspicious or cheating
      await this.updateAttemptSuspicionStatus(attempt_id);

      logger.info(`Created proctoring warning ${warning.id} for attempt ${attempt_id}`);

      // Emit real-time warning to instructor via WebSocket
      const { getIO } = require('../websocket/socketManager');
      const io = getIO();
      if (io) {
        io.to(`instructor-${attempt.instructor_id}`).emit('proctoring-warning', {
          warning: {
            id: warning.id,
            attempt_id: warning.attempt_id,
            user_id: warning.user_id,
            exam_id: warning.exam_id,
            warning_type: warning.warning_type,
            severity: warning.severity,
            timestamp: warning.timestamp
          }
        });
      }

      res.status(201).json({
        success: true,
        data: warning
      });
    } catch (error) {
      logger.error('Error creating proctoring warning:', error);
      res.status(500).json({
        success: false,
        error: {
          code: 'INTERNAL_ERROR',
          message: 'Failed to create proctoring warning'
        }
      });
    }
  }

  /**
   * GET /api/v1/proctoring/warnings
   * Get proctoring warnings (teachers/admins only)
   */
  static async getWarnings(req, res) {
    try {
      const { role, id: userId } = req.user;
      if (role !== 'teacher' && role !== 'admin') {
        return res.status(403).json({
          success: false,
          error: {
            code: 'ACCESS_DENIED',
            message: 'Access denied'
          }
        });
      }

      const { exam_id, user_id, warning_type, severity, page = 1, limit = 50 } = req.query;

      let whereClause = 'WHERE 1=1';
      let params = [];
      let paramIndex = 1;

      if (exam_id) {
        whereClause += ` AND pw.exam_id = $${paramIndex}`;
        params.push(exam_id);
        paramIndex++;
      }

      if (user_id) {
        whereClause += ` AND pw.user_id = $${paramIndex}`;
        params.push(user_id);
        paramIndex++;
      }

      if (warning_type) {
        whereClause += ` AND pw.warning_type = $${paramIndex}`;
        params.push(warning_type);
        paramIndex++;
      }

      if (severity) {
        whereClause += ` AND pw.severity = $${paramIndex}`;
        params.push(severity);
        paramIndex++;
      }

      // For teachers, only show warnings for their exams
      if (role === 'teacher') {
        whereClause += ` AND e.instructor_id = $${paramIndex}`;
        params.push(userId);
        paramIndex++;
      }

      const offset = (page - 1) * limit;

      const result = await query(`
        SELECT pw.*, 
               u.first_name || ' ' || u.last_name as student_name,
               u.email as student_email,
               e.title as exam_title,
               a.started_at as attempt_started_at
        FROM proctoring_warnings pw
        JOIN users u ON pw.user_id = u.id
        JOIN exams e ON pw.exam_id = e.id
        JOIN attempts a ON pw.attempt_id = a.id
        ${whereClause}
        ORDER BY pw.timestamp DESC
        LIMIT $${paramIndex} OFFSET $${paramIndex + 1}
      `, [...params, limit, offset]);

      const countResult = await query(`
        SELECT COUNT(*) as total
        FROM proctoring_warnings pw
        JOIN exams e ON pw.exam_id = e.id
        ${whereClause}
      `, params);

      logger.info(`User ${userId} retrieved ${result.rows.length} proctoring warnings`);

      res.json({
        success: true,
        data: result.rows,
        pagination: {
          page: parseInt(page),
          limit: parseInt(limit),
          total: parseInt(countResult.rows[0].total),
          pages: Math.ceil(countResult.rows[0].total / limit)
        }
      });
    } catch (error) {
      logger.error('Error fetching proctoring warnings:', error);
      res.status(500).json({
        success: false,
        error: {
          code: 'INTERNAL_ERROR',
          message: 'Failed to fetch proctoring warnings'
        }
      });
    }
  }

  /**
   * PUT /api/v1/proctoring/warnings/:id/acknowledge
   * Acknowledge proctoring warning (teachers/admins only)
   */
  static async acknowledgeWarning(req, res) {
    try {
      const { id } = req.params;
      const { role, id: userId } = req.user;

      if (role !== 'teacher' && role !== 'admin') {
        return res.status(403).json({
          success: false,
          error: {
            code: 'ACCESS_DENIED',
            message: 'Access denied'
          }
        });
      }

      // Check if warning exists and user has access
      const warningCheck = await query(`
        SELECT pw.*, e.instructor_id
        FROM proctoring_warnings pw
        JOIN exams e ON pw.exam_id = e.id
        WHERE pw.id = $1
      `, [id]);

      if (warningCheck.rows.length === 0) {
        return res.status(404).json({
          success: false,
          error: {
            code: 'WARNING_NOT_FOUND',
            message: 'Warning not found'
          }
        });
      }

      const warning = warningCheck.rows[0];

      if (role === 'teacher' && warning.instructor_id !== userId) {
        return res.status(403).json({
          success: false,
          error: {
            code: 'ACCESS_DENIED',
            message: 'Access denied to this warning'
          }
        });
      }

      await query(`
        UPDATE proctoring_warnings 
        SET is_acknowledged = TRUE 
        WHERE id = $1
      `, [id]);

      logger.info(`User ${userId} acknowledged warning ${id}`);

      res.json({
        success: true,
        message: 'Warning acknowledged successfully'
      });
    } catch (error) {
      logger.error('Error acknowledging warning:', error);
      res.status(500).json({
        success: false,
        error: {
          code: 'INTERNAL_ERROR',
          message: 'Failed to acknowledge warning'
        }
      });
    }
  }

  /**
   * GET /api/v1/proctoring/analytics
   * Get proctoring analytics (teachers/admins only)
   */
  static async getProctoringAnalytics(req, res) {
    try {
      const { role, id: userId } = req.user;
      if (role !== 'teacher' && role !== 'admin') {
        return res.status(403).json({
          success: false,
          error: {
            code: 'ACCESS_DENIED',
            message: 'Access denied'
          }
        });
      }

      const { exam_id } = req.query;

      let whereClause = 'WHERE 1=1';
      let params = [];
      let paramIndex = 1;

      if (exam_id) {
        whereClause += ` AND e.id = $${paramIndex}`;
        params.push(exam_id);
        paramIndex++;
      }

      // For teachers, only show analytics for their exams
      if (role === 'teacher') {
        whereClause += ` AND e.instructor_id = $${paramIndex}`;
        params.push(userId);
        paramIndex++;
      }

      // Get warning statistics
      const warningStats = await query(`
        SELECT 
          COUNT(*) as total_warnings,
          COUNT(CASE WHEN is_acknowledged = FALSE THEN 1 END) as unacknowledged_warnings,
          COUNT(CASE WHEN severity = 'critical' THEN 1 END) as critical_warnings,
          COUNT(CASE WHEN severity = 'high' THEN 1 END) as high_warnings,
          COUNT(CASE WHEN severity = 'medium' THEN 1 END) as medium_warnings,
          COUNT(CASE WHEN severity = 'low' THEN 1 END) as low_warnings
        FROM proctoring_warnings pw
        JOIN exams e ON pw.exam_id = e.id
        ${whereClause}
      `, params);

      // Get suspicious attempts (3+ warnings)
      const suspiciousAttempts = await query(`
        SELECT 
          COUNT(DISTINCT pw.attempt_id) as suspicious_attempts,
          COUNT(DISTINCT pw.user_id) as suspicious_students
        FROM proctoring_warnings pw
        JOIN exams e ON pw.exam_id = e.id
        ${whereClause}
        GROUP BY pw.attempt_id
        HAVING COUNT(pw.id) >= 3
      `, params);

      // Get cheating attempts (5+ warnings)
      const cheatingAttempts = await query(`
        SELECT 
          COUNT(DISTINCT pw.attempt_id) as cheating_attempts,
          COUNT(DISTINCT pw.user_id) as cheating_students
        FROM proctoring_warnings pw
        JOIN exams e ON pw.exam_id = e.id
        ${whereClause}
        GROUP BY pw.attempt_id
        HAVING COUNT(pw.id) >= 5
      `, params);

      // Get warning types distribution
      const warningTypes = await query(`
        SELECT 
          pw.warning_type,
          COUNT(*) as count,
          ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) as percentage
        FROM proctoring_warnings pw
        JOIN exams e ON pw.exam_id = e.id
        ${whereClause}
        GROUP BY pw.warning_type
        ORDER BY count DESC
      `, params);

      logger.info(`User ${userId} retrieved proctoring analytics`);

      res.json({
        success: true,
        data: {
          warning_stats: warningStats.rows[0] || {},
          suspicious_attempts: suspiciousAttempts.rows[0] || { suspicious_attempts: 0, suspicious_students: 0 },
          cheating_attempts: cheatingAttempts.rows[0] || { cheating_attempts: 0, cheating_students: 0 },
          warning_types: warningTypes.rows
        }
      });
    } catch (error) {
      logger.error('Error fetching proctoring analytics:', error);
      res.status(500).json({
        success: false,
        error: {
          code: 'INTERNAL_ERROR',
          message: 'Failed to fetch proctoring analytics'
        }
      });
    }
  }

  /**
   * Update attempt suspicion status based on warning count
   */
  static async updateAttemptSuspicionStatus(attemptId) {
    try {
      const warningCount = await query(`
        SELECT COUNT(*) as count, severity
        FROM proctoring_warnings
        WHERE attempt_id = $1
        GROUP BY severity
      `, [attemptId]);

      const totalWarnings = warningCount.rows.reduce((sum, row) => sum + parseInt(row.count), 0);
      const criticalWarnings = warningCount.rows.find(row => row.severity === 'critical')?.count || 0;
      const highWarnings = warningCount.rows.find(row => row.severity === 'high')?.count || 0;

      let cheatingFlags = {};

      if (totalWarnings >= 5) {
        cheatingFlags.cheating_detected = true;
        cheatingFlags.warning_count = totalWarnings;
      } else if (totalWarnings >= 3) {
        cheatingFlags.suspicious = true;
        cheatingFlags.warning_count = totalWarnings;
      }

      if (criticalWarnings >= 1) {
        cheatingFlags.critical_violations = criticalWarnings;
      }

      if (highWarnings >= 2) {
        cheatingFlags.multiple_high_severity = true;
      }

      const isSuspicious = totalWarnings >= 3 || criticalWarnings >= 1 || highWarnings >= 2;

      await query(`
        UPDATE attempts 
        SET is_suspicious = $1, cheating_flags = $2
        WHERE id = $3
      `, [isSuspicious, Object.keys(cheatingFlags).length > 0 ? JSON.stringify(cheatingFlags) : null, attemptId]);

      logger.info(`Updated attempt ${attemptId} suspicion status: ${isSuspicious}`);
    } catch (error) {
      logger.error('Error updating attempt suspicion status:', error);
    }
  }
}

module.exports = ProctoringController;
