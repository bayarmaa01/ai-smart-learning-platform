const express = require('express');
const router = express.Router();
const axios = require('axios');
const { logger } = require('../utils/logger');

// Simple chat endpoint that connects directly to Ollama
router.post('/chat', async (req, res) => {
  try {
    const { message } = req.body;
    
    if (!message) {
      return res.status(400).json({
        success: false,
        error: 'Message is required'
      });
    }

    const ollamaUrl = process.env.OLLAMA_URL || 'http://host.docker.internal:11434';
    const model = process.env.OLLAMA_MODEL || 'gemma4:31b';

    logger.info(`Sending message to Ollama: ${message.substring(0, 100)}...`);

    const response = await axios.post(`${ollamaUrl}/api/generate`, {
      model: model,
      prompt: `You are a helpful AI learning assistant. Please respond to this message in a friendly, educational way: "${message}"

Provide a helpful, concise response that is appropriate for a learning platform.`,
      stream: false,
      options: {
        temperature: 0.7,
        top_p: 0.9,
        max_tokens: 1000
      }
    }, {
      timeout: 30000,
      headers: {
        'Content-Type': 'application/json'
      }
    });

    if (response.data && response.data.response) {
      logger.info('Received response from Ollama');
      res.json({
        success: true,
        data: {
          response: response.data.response.trim(),
          type: 'answer'
        }
      });
    } else {
      throw new Error('Invalid response from Ollama');
    }

  } catch (error) {
    logger.error('Chat endpoint error:', error.message);
    res.status(500).json({
      success: false,
      error: 'Failed to process chat message',
      fallback: 'I apologize, but I\'m having trouble processing your message right now. Please try again.'
    });
  }
});

// Health check for AI service
router.get('/health', async (req, res) => {
  try {
    const ollamaUrl = process.env.OLLAMA_URL || 'http://host.docker.internal:11434';
    const model = process.env.OLLAMA_MODEL || 'gemma4:31b';

    const response = await axios.get(`${ollamaUrl}/api/tags`, {
      timeout: 5000
    });

    const hasModel = response.data.models.some(m => m.name === model);

    res.json({
      success: true,
      data: {
        status: 'healthy',
        model: model,
        available: hasModel,
        models: response.data.models.map(m => m.name)
      }
    });

  } catch (error) {
    logger.error('AI health check error:', error.message);
    res.status(500).json({
      success: false,
      error: 'AI service health check failed',
      data: {
        status: 'unhealthy',
        error: error.message
      }
    });
  }
});

module.exports = router;
