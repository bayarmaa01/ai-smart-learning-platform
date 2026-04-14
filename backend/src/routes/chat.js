const express = require('express');
const router = express.Router();
const axios = require('axios');
const { logger } = require('../utils/logger');

const getOllamaUrls = () => {
  const primary = process.env.OLLAMA_URL || 'http://host.minikube.internal:11434';
  const fallbackRaw = process.env.OLLAMA_FALLBACK_URLS || '';
  return [...new Set([primary, ...fallbackRaw.split(',')].map((x) => x.trim()).filter(Boolean))];
};

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

    const ollamaUrls = getOllamaUrls();
    const model = process.env.OLLAMA_MODEL || 'gemma4:31b';

    logger.info(`Sending message to Ollama: ${message.substring(0, 100)}...`);

    let response;
    let lastError;
    for (const baseUrl of ollamaUrls) {
      try {
        response = await axios.post(`${baseUrl}/api/generate`, {
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
          timeout: 45000,
          headers: {
            'Content-Type': 'application/json'
          }
        });
        break;
      } catch (err) {
        lastError = err;
        logger.warn(`Ollama request failed for ${baseUrl}: ${err.message}`);
      }
    }

    if (!response) {
      throw lastError || new Error('All configured Ollama endpoints failed');
    }

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
    const ollamaUrls = getOllamaUrls();
    const model = process.env.OLLAMA_MODEL || 'gemma4:31b';
    let response;
    for (const baseUrl of ollamaUrls) {
      try {
        response = await axios.get(`${baseUrl}/api/tags`, { timeout: 5000 });
        if (response) break;
      } catch (err) {
        logger.warn(`AI health check failed for ${baseUrl}: ${err.message}`);
      }
    }

    if (!response) {
      throw new Error('No Ollama endpoint reachable');
    }

    const hasModel = response.data.models.some(m => m.name === model || m.name.startsWith(`${model}:`));

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
