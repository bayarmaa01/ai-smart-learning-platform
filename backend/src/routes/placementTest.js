const express = require('express');
const router = express.Router();
const PlacementTestController = require('../controllers/placementTestController');
const { authMiddleware } = require('../middleware/auth');
const { body } = require('express-validator');
const { validate } = require('../middleware/validate');

// Public routes
router.get('/', PlacementTestController.getPlacementTests);
router.get('/:id', PlacementTestController.getPlacementTest);

// Protected routes
router.use(authMiddleware);

router.post('/:id/submit', [
  body('answers').isArray().withMessage('Answers must be an array'),
  body('answers.*').isInt({ min: 0 }).withMessage('Each answer must be a non-negative integer')
], validate, PlacementTestController.submitPlacementTest);

router.get('/results/my', PlacementTestController.getUserResults);

// Admin/Instructor only routes
router.post('/', [
  body('title').trim().isLength({ min: 1, max: 255 }).withMessage('Title must be 1-255 characters'),
  body('description').trim().isLength({ min: 1, max: 1000 }).withMessage('Description must be 1-1000 characters'),
  body('questions').isArray({ min: 3 }).withMessage('At least 3 questions are required'),
  body('questions.*.question').trim().isLength({ min: 1, max: 500 }).withMessage('Question text is required'),
  body('questions.*.options').isArray({ min: 2 }).withMessage('Each question must have at least 2 options'),
  body('questions.*.correct').isInt({ min: 0 }).withMessage('Correct answer index is required')
], validate, PlacementTestController.createPlacementTest);

module.exports = router;
