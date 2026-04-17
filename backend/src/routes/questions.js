const express = require('express');
const { body, param } = require('express-validator');
const QuestionController = require('../controllers/questionController');
const { authenticate, authorize } = require('../middleware/auth');
const { validate } = require('../middleware/validator');

const router = express.Router();

// Apply authentication to all routes
router.use(authenticate);

// Validation rules
const createQuestionValidation = [
  body('exam_id')
    .isUUID()
    .withMessage('Valid exam ID is required'),
  body('question_text')
    .trim()
    .isLength({ min: 1, max: 2000 })
    .withMessage('Question text must be 1-2000 characters'),
  body('question_type')
    .optional()
    .isIn(['multiple_choice', 'true_false', 'short_answer', 'essay'])
    .withMessage('Invalid question type'),
  body('options')
    .optional()
    .isArray({ min: 2 })
    .withMessage('Options must be an array with at least 2 items'),
  body('options.*')
    .optional()
    .isString()
    .trim()
    .isLength({ min: 1, max: 500 })
    .withMessage('Each option must be 1-500 characters'),
  body('correct_answer')
    .trim()
    .isLength({ min: 1, max: 1000 })
    .withMessage('Correct answer is required and must be less than 1000 characters'),
  body('explanation')
    .optional()
    .trim()
    .isLength({ max: 2000 })
    .withMessage('Explanation must be less than 2000 characters'),
  body('points')
    .optional()
    .isInt({ min: 1, max: 100 })
    .withMessage('Points must be between 1 and 100'),
  body('order_index')
    .optional()
    .isInt({ min: 0 })
    .withMessage('Order index must be a non-negative integer')
];

const updateQuestionValidation = [
  param('id').isUUID().withMessage('Valid question ID is required'),
  body('question_text')
    .optional()
    .trim()
    .isLength({ min: 1, max: 2000 })
    .withMessage('Question text must be 1-2000 characters'),
  body('question_type')
    .optional()
    .isIn(['multiple_choice', 'true_false', 'short_answer', 'essay'])
    .withMessage('Invalid question type'),
  body('options')
    .optional()
    .isArray({ min: 2 })
    .withMessage('Options must be an array with at least 2 items'),
  body('options.*')
    .optional()
    .isString()
    .trim()
    .isLength({ min: 1, max: 500 })
    .withMessage('Each option must be 1-500 characters'),
  body('correct_answer')
    .optional()
    .trim()
    .isLength({ min: 1, max: 1000 })
    .withMessage('Correct answer must be less than 1000 characters'),
  body('explanation')
    .optional()
    .trim()
    .isLength({ max: 2000 })
    .withMessage('Explanation must be less than 2000 characters'),
  body('points')
    .optional()
    .isInt({ min: 1, max: 100 })
    .withMessage('Points must be between 1 and 100'),
  body('order_index')
    .optional()
    .isInt({ min: 0 })
    .withMessage('Order index must be a non-negative integer')
];

const bulkCreateValidation = [
  body('exam_id')
    .isUUID()
    .withMessage('Valid exam ID is required'),
  body('questions')
    .isArray({ min: 1 })
    .withMessage('Questions array is required and must not be empty'),
  body('questions.*.question_text')
    .trim()
    .isLength({ min: 1, max: 2000 })
    .withMessage('Question text must be 1-2000 characters'),
  body('questions.*.question_type')
    .optional()
    .isIn(['multiple_choice', 'true_false', 'short_answer', 'essay'])
    .withMessage('Invalid question type'),
  body('questions.*.options')
    .optional()
    .isArray({ min: 2 })
    .withMessage('Options must be an array with at least 2 items'),
  body('questions.*.correct_answer')
    .trim()
    .isLength({ min: 1, max: 1000 })
    .withMessage('Correct answer is required and must be less than 1000 characters'),
  body('questions.*.explanation')
    .optional()
    .trim()
    .isLength({ max: 2000 })
    .withMessage('Explanation must be less than 2000 characters'),
  body('questions.*.points')
    .optional()
    .isInt({ min: 1, max: 100 })
    .withMessage('Points must be between 1 and 100'),
  body('questions.*.order_index')
    .optional()
    .isInt({ min: 0 })
    .withMessage('Order index must be a non-negative integer')
];

const questionIdValidation = [
  param('id').isUUID().withMessage('Valid question ID is required')
];

// Routes
/**
 * POST /api/v1/questions
 * Create new question (teachers and admins only)
 */
router.post('/', [
  authorize(['teacher', 'admin']),
  ...createQuestionValidation
], validate, QuestionController.createQuestion);

/**
 * PUT /api/v1/questions/:id
 * Update question (teachers and admins only)
 */
router.put('/:id', [
  authorize(['teacher', 'admin']),
  ...updateQuestionValidation
], validate, QuestionController.updateQuestion);

/**
 * DELETE /api/v1/questions/:id
 * Delete question (teachers and admins only)
 */
router.delete('/:id', [
  authorize(['teacher', 'admin']),
  questionIdValidation
], validate, QuestionController.deleteQuestion);

/**
 * POST /api/v1/questions/bulk
 * Bulk create questions (teachers and admins only)
 */
router.post('/bulk', [
  authorize(['teacher', 'admin']),
  ...bulkCreateValidation
], validate, QuestionController.bulkCreateQuestions);

module.exports = router;
