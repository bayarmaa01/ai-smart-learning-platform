const express = require('express');
const router = express.Router();
const ollamaService = require('../services/ollamaService');
const { logger } = require('../utils/logger');

// POST /api/chat - Chat with AI
router.post('/chat', async (req, res) => {
  try {
    const { message } = req.body;
    
    if (!message || typeof message !== 'string' || message.trim().length === 0) {
      return res.status(400).json({
        success: false,
        error: 'Message is required and must be a non-empty string'
      });
    }

    if (message.length > 5000) {
      return res.status(400).json({
        success: false,
        error: 'Message too long (max 5000 characters)'
      });
    }

    const enhancedMessage = `You are a helpful AI learning assistant for an educational platform. Please respond to this message in a friendly, educational way: "${message}"

Provide a helpful, concise response that is appropriate for a learning platform. Be encouraging and supportive.`;

    const result = await ollamaService.generateResponse(enhancedMessage);

    res.json({
      success: true,
      reply: result.response,
      model: result.model,
      fallback: result.fallback || false,
      tokens: result.tokens || 0
    });

  } catch (error) {
    logger.error('Chat endpoint error:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to process chat message',
      reply: 'I apologize, but I\'m having trouble processing your message right now. Please try again.'
    });
  }
});

// GET /api/health - AI service health check
router.get('/health', async (req, res) => {
  try {
    const health = await ollamaService.checkHealth();
    
    res.json({
      status: health.status,
      model: health.model,
      available: health.available,
      baseUrl: health.baseUrl,
      totalModels: health.totalModels || 0,
      models: health.models || [],
      error: health.error || null
    });

  } catch (error) {
    logger.error('AI health check error:', error);
    res.status(500).json({
      status: 'error',
      error: 'AI service health check failed',
      model: process.env.OLLAMA_MODEL || 'gemma4:31b'
    });
  }
});

module.exports = router;
