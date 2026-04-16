const express = require('express');
const router = express.Router();
const AIController = require('../controllers/ai.controller');
const { verifyToken } = require('../middleware/auth');
const rateLimiter = require('../middleware/rateLimiter');

/**
 * AI Routes - Smart Learning Platform
 * All endpoints use Ollama (gemma:2b) for AI-powered features
 */

// Apply authentication and rate limiting to all AI routes
router.use(verifyToken);
router.use(rateLimiter);

/**
 * POST /ai/tutor
 * AI Tutor - Explain topics like a teacher
 */
router.post('/tutor', AIController.tutor);

/**
 * POST /ai/quiz
 * AI Quiz Generator - Generate multiple choice questions
 */
router.post('/quiz', AIController.quiz);

/**
 * POST /ai/explain
 * AI Smart Explanation - Topic explanations with examples
 */
router.post('/explain', AIController.explain);

/**
 * POST /ai/chat
 * AI Chat - General chat interface
 */
router.post('/chat', AIController.chat);

/**
 * POST /ai/debug
 * AI Error Helper - Debug DevOps issues
 */
router.post('/debug', AIController.debug);

/**
 * GET /ai/health
 * AI Service Health Check
 */
router.get('/health', AIController.health);

module.exports = router;
