const express = require('express');
const { body, param, query } = require('express-validator');
const ExamController = require('../controllers/examController');
const { verifyToken, authorize } = require('../middleware/auth');
const { validate } = require('../middleware/validate');

const router = express.Router();

// Apply authentication to all routes
router.use(verifyToken);

// Validation rules
const examValidation = [
  body('title')
    .trim()
    .isLength({ min: 1, max: 500 })
    .withMessage('Title must be 1-500 characters'),
  body('description')
    .optional()
    .trim()
    .isLength({ max: 2000 })
    .withMessage('Description must be less than 2000 characters'),
  body('course_id')
    .isUUID()
    .withMessage('Valid course ID is required'),
  body('duration_minutes')
    .isInt({ min: 1, max: 480 })
    .withMessage('Duration must be between 1 and 480 minutes'),
  body('start_time')
    .optional()
    .isISO8601()
    .withMessage('Start time must be a valid date'),
  body('end_time')
    .optional()
    .isISO8601()
    .withMessage('End time must be a valid date'),
  body('instructions')
    .optional()
    .trim()
    .isLength({ max: 5000 })
    .withMessage('Instructions must be less than 5000 characters'),
  body('max_attempts')
    .optional()
    .isInt({ min: 1, max: 10 })
    .withMessage('Max attempts must be between 1 and 10'),
  body('passing_score')
    .optional()
    .isInt({ min: 0, max: 100 })
    .withMessage('Passing score must be between 0 and 100'),
  body('shuffle_questions')
    .optional()
    .isBoolean()
    .withMessage('Shuffle questions must be a boolean'),
  body('show_results')
    .optional()
    .isBoolean()
    .withMessage('Show results must be a boolean')
];

const updateExamValidation = [
  param('id').isUUID().withMessage('Valid exam ID is required'),
  body('title')
    .optional()
    .trim()
    .isLength({ min: 1, max: 500 })
    .withMessage('Title must be 1-500 characters'),
  body('description')
    .optional()
    .trim()
    .isLength({ max: 2000 })
    .withMessage('Description must be less than 2000 characters'),
  body('duration_minutes')
    .optional()
    .isInt({ min: 1, max: 480 })
    .withMessage('Duration must be between 1 and 480 minutes'),
  body('start_time')
    .optional()
    .isISO8601()
    .withMessage('Start time must be a valid date'),
  body('end_time')
    .optional()
    .isISO8601()
    .withMessage('End time must be a valid date'),
  body('instructions')
    .optional()
    .trim()
    .isLength({ max: 5000 })
    .withMessage('Instructions must be less than 5000 characters'),
  body('max_attempts')
    .optional()
    .isInt({ min: 1, max: 10 })
    .withMessage('Max attempts must be between 1 and 10'),
  body('passing_score')
    .optional()
    .isInt({ min: 0, max: 100 })
    .withMessage('Passing score must be between 0 and 100'),
  body('shuffle_questions')
    .optional()
    .isBoolean()
    .withMessage('Shuffle questions must be a boolean'),
  body('show_results')
    .optional()
    .isBoolean()
    .withMessage('Show results must be a boolean'),
  body('status')
    .optional()
    .isIn(['draft', 'published', 'ongoing', 'completed', 'archived'])
    .withMessage('Status must be one of: draft, published, ongoing, completed, archived')
];

const examIdValidation = [
  param('id').isUUID().withMessage('Valid exam ID is required')
];

// Routes
/**
 * GET /api/v1/exams
 * Get all exams (filtered by user role)
 * 
 * Query params:
 * - status: Filter by exam status
 * - course_id: Filter by course ID
 * - page: Page number (default: 1)
 * - limit: Items per page (default: 20)
 */
router.get('/', [
  query('status')
    .optional()
    .isIn(['draft', 'published', 'ongoing', 'completed', 'archived'])
    .withMessage('Invalid status'),
  query('course_id')
    .optional()
    .isUUID()
    .withMessage('Invalid course ID'),
  query('page')
    .optional()
    .isInt({ min: 1 })
    .withMessage('Page must be a positive integer'),
  query('limit')
    .optional()
    .isInt({ min: 1, max: 100 })
    .withMessage('Limit must be between 1 and 100')
], validate, ExamController.getExams);

/**
 * GET /api/v1/exams/:id
 * Get exam by ID
 */
router.get('/:id', examIdValidation, validate, ExamController.getExamById);

/**
 * POST /api/v1/exams
 * Create new exam (teachers and admins only)
 */
router.post('/', [
  authorize(['teacher', 'admin']),
  ...examValidation
], validate, ExamController.createExam);

/**
 * PUT /api/v1/exams/:id
 * Update exam (teachers and admins only)
 */
router.put('/:id', [
  authorize(['teacher', 'admin']),
  ...updateExamValidation
], validate, ExamController.updateExam);

/**
 * DELETE /api/v1/exams/:id
 * Delete exam (teachers and admins only)
 */
router.delete('/:id', [
  authorize(['teacher', 'admin']),
  examIdValidation
], validate, ExamController.deleteExam);

/**
 * GET /api/v1/exams/:id/questions
 * Get exam questions
 */
router.get('/:id/questions', examIdValidation, validate, ExamController.getExamQuestions);

module.exports = router;
