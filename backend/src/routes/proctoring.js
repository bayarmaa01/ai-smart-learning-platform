const express = require('express');
const { body, param, query } = require('express-validator');
const ProctoringController = require('../controllers/proctoringController');
const { verifyToken, authorize } = require('../middleware/auth');
const { validate } = require('../middleware/validate');

const router = express.Router();

// Apply authentication to all routes
router.use(verifyToken);

// Validation rules
const createWarningValidation = [
  body('attempt_id')
    .isUUID()
    .withMessage('Valid attempt ID is required'),
  body('user_id')
    .isUUID()
    .withMessage('Valid user ID is required'),
  body('exam_id')
    .isUUID()
    .withMessage('Valid exam ID is required'),
  body('warning_type')
    .isIn(['tab_switch', 'fullscreen_exit', 'no_face', 'multiple_faces', 'suspicious_behavior'])
    .withMessage('Invalid warning type'),
  body('severity')
    .optional()
    .isIn(['low', 'medium', 'high', 'critical'])
    .withMessage('Invalid severity'),
  body('details')
    .optional()
    .isObject()
    .withMessage('Details must be an object')
];

const warningIdValidation = [
  param('id').isUUID().withMessage('Valid warning ID is required')
];

const getWarningsValidation = [
  query('exam_id')
    .optional()
    .isUUID()
    .withMessage('Valid exam ID is required'),
  query('user_id')
    .optional()
    .isUUID()
    .withMessage('Valid user ID is required'),
  query('warning_type')
    .optional()
    .isIn(['tab_switch', 'fullscreen_exit', 'no_face', 'multiple_faces', 'suspicious_behavior'])
    .withMessage('Invalid warning type'),
  query('severity')
    .optional()
    .isIn(['low', 'medium', 'high', 'critical'])
    .withMessage('Invalid severity'),
  query('page')
    .optional()
    .isInt({ min: 1 })
    .withMessage('Page must be a positive integer'),
  query('limit')
    .optional()
    .isInt({ min: 1, max: 100 })
    .withMessage('Limit must be between 1 and 100')
];

const analyticsValidation = [
  query('exam_id')
    .optional()
    .isUUID()
    .withMessage('Valid exam ID is required')
];

// Routes
/**
 * POST /api/v1/proctoring/warnings
 * Create proctoring warning (from AI service or internal monitoring)
 * This endpoint should be protected with API key for AI service access
 */
router.post('/warnings', createWarningValidation, validate, ProctoringController.createWarning);

/**
 * GET /api/v1/proctoring/warnings
 * Get proctoring warnings (teachers and admins only)
 */
router.get('/warnings', [
  authorize(['teacher', 'admin']),
  ...getWarningsValidation
], validate, ProctoringController.getWarnings);

/**
 * PUT /api/v1/proctoring/warnings/:id/acknowledge
 * Acknowledge proctoring warning (teachers and admins only)
 */
router.put('/warnings/:id/acknowledge', [
  authorize(['teacher', 'admin']),
  warningIdValidation
], validate, ProctoringController.acknowledgeWarning);

/**
 * GET /api/v1/proctoring/analytics
 * Get proctoring analytics (teachers and admins only)
 */
router.get('/analytics', [
  authorize(['teacher', 'admin']),
  ...analyticsValidation
], validate, ProctoringController.getProctoringAnalytics);

module.exports = router;
