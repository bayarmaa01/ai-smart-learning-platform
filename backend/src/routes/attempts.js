const express = require('express');
const { body, param, query } = require('express-validator');
const AttemptController = require('../controllers/attemptController');
const { verifyToken, authorize } = require('../middleware/auth');
const { validate } = require('../middleware/validate');

const router = express.Router();

// Apply authentication to all routes
router.use(verifyToken);

// Validation rules
const startAttemptValidation = [
  body('exam_id')
    .isUUID()
    .withMessage('Valid exam ID is required')
];

const submitAttemptValidation = [
  body('attempt_id')
    .isUUID()
    .withMessage('Valid attempt ID is required'),
  body('answers')
    .isObject()
    .withMessage('Answers must be an object'),
  body('answers.*')
    .optional()
    .isString()
    .withMessage('All answers must be strings')
];

const attemptIdValidation = [
  param('id').isUUID().withMessage('Valid attempt ID is required')
];

const resultsQueryValidation = [
  query('exam_id')
    .optional()
    .isUUID()
    .withMessage('Valid exam ID is required'),
  query('status')
    .optional()
    .isIn(['in_progress', 'submitted', 'graded', 'expired'])
    .withMessage('Invalid status'),
  query('page')
    .optional()
    .isInt({ min: 1 })
    .withMessage('Page must be a positive integer'),
  query('limit')
    .optional()
    .isInt({ min: 1, max: 100 })
    .withMessage('Limit must be between 1 and 100')
];

// Routes
/**
 * POST /api/v1/attempts/start
 * Start a new exam attempt (students only)
 */
router.post('/start', [
  authorize(['student']),
  ...startAttemptValidation
], validate, AttemptController.startAttempt);

/**
 * POST /api/v1/attempts/submit
 * Submit exam attempt with answers (students only)
 */
router.post('/submit', [
  authorize(['student']),
  ...submitAttemptValidation
], validate, AttemptController.submitAttempt);

/**
 * GET /api/v1/attempts/:id
 * Get attempt details
 */
router.get('/:id', attemptIdValidation, validate, AttemptController.getAttempt);

/**
 * GET /api/v1/attempts/:id/warnings
 * Get proctoring warnings for an attempt
 */
router.get('/:id/warnings', attemptIdValidation, validate, AttemptController.getAttemptWarnings);

/**
 * GET /api/v1/student/results
 * Get student's exam results (students only)
 */
router.get('/student/results', [
  authorize(['student']),
  ...resultsQueryValidation
], validate, AttemptController.getStudentResults);

/**
 * GET /api/v1/teacher/results
 * Get teacher's exam results (teachers only)
 */
router.get('/teacher/results', [
  authorize(['teacher', 'admin']),
  ...resultsQueryValidation
], validate, AttemptController.getTeacherResults);

module.exports = router;
