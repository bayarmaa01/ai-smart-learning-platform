const express = require('express');
const { body, validationResult } = require('express-validator');
const { verifyToken } = require('../middleware/auth');
const { getRedis } = require('../config/database');
const logger = require('../utils/logger');

const router = express.Router();
const OLLAMA_URL = process.env.OLLAMA_URL || 'http://ollama:11434';
const OLLAMA_MODEL = process.env.OLLAMA_MODEL || 'gemma2:9b';

// AI Chat endpoint
router.post('/', verifyToken, [
  body('message').notEmpty().trim(),
  body('courseId').optional().isUUID()
], async (req, res) => {
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

    const { message, courseId } = req.body;
    const userId = req.user.userId;

    // Get user context for course-aware AI
    let courseContext = '';
    if (courseId) {
      const courseResult = await getRedis().query('SELECT title, description FROM courses WHERE id = $1', [courseId]);
      if (courseResult.rows.length > 0) {
        courseContext = `Context: User is enrolled in course "${courseResult.rows[0].title}". `;
      }
    }

    // Store chat session
    const sessionId = `chat:${userId}:${courseId || 'general'}`;
    const sessionData = {
      userId,
      courseId: courseId || null,
      messages: [],
      createdAt: new Date().toISOString()
    };

    await getRedis().setex(sessionId, 3600, JSON.stringify(sessionData));

    // Prepare AI prompt
    const systemPrompt = `You are an AI tutor for an educational platform. Be helpful, educational, and encouraging.
${courseContext}
Keep responses concise but informative. If asked about complex topics, break them down into manageable steps.
If you don't know something, admit it and suggest where the user might find the information.`;

    const userPrompt = `User: ${message}`;

    // Call Ollama API
    try {
      const response = await fetch(`${OLLAMA_URL}/api/generate`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          model: OLLAMA_MODEL,
          prompt: `${systemPrompt}\n\n${userPrompt}`,
          stream: false,
          options: {
            temperature: 0.7,
            max_tokens: 1000,
            top_p: 0.9
          }
        })
      });

      if (!response.ok) {
        throw new Error(`Ollama API error: ${response.status}`);
      }

      const aiResponse = await response.json();
      const aiMessage = aiResponse.response || 'I apologize, but I encountered an error processing your request.';

      // Update chat session
      const currentSession = JSON.parse(await getRedis().get(sessionId) || '{}');
      currentSession.messages.push(
        { role: 'user', content: message, timestamp: new Date().toISOString() },
        { role: 'assistant', content: aiMessage, timestamp: new Date().toISOString() }
      );
      await getRedis().setex(sessionId, 3600, JSON.stringify(currentSession));

      logger.info(`AI chat response for user ${userId}`);

      res.json({
        success: true,
        data: {
          message: aiMessage,
          sessionId,
          courseId: courseId || null
        }
      });
    } catch (aiError) {
      logger.error('Ollama API error:', aiError);
      res.status(500).json({
        success: false,
        error: {
          code: 'AI_SERVICE_ERROR',
          message: 'AI service temporarily unavailable'
        }
      });
    }
  } catch (error) {
    logger.error('Chat endpoint error:', error);
    res.status(500).json({
      success: false,
      error: {
        code: 'INTERNAL_ERROR',
        message: 'Chat request failed'
      }
    });
  }
});

// Get chat history
router.get('/history/:sessionId?', verifyToken, async (req, res) => {
  try {
    const userId = req.user.userId;
    const { sessionId } = req.params;

    const actualSessionId = sessionId || `chat:${userId}:general`;
    
    const sessionData = await getRedis().get(actualSessionId);
    if (!sessionData) {
      return res.json({
        success: true,
        data: {
          messages: [],
          sessionId: actualSessionId
        }
      });
    }

    const session = JSON.parse(sessionData);
    
    res.json({
      success: true,
      data: {
        messages: session.messages || [],
        sessionId: actualSessionId,
        courseId: session.courseId
      }
    });
  } catch (error) {
    logger.error('Chat history error:', error);
    res.status(500).json({
      success: false,
      error: {
        code: 'INTERNAL_ERROR',
        message: 'Failed to retrieve chat history'
      }
    });
  }
});

// Clear chat session
router.delete('/session/:sessionId', verifyToken, async (req, res) => {
  try {
    const userId = req.user.userId;
    const { sessionId } = req.params;
    const actualSessionId = sessionId || `chat:${userId}:general`;

    await getRedis().del(actualSessionId);
    
    logger.info(`Chat session cleared: ${actualSessionId}`);

    res.json({
      success: true,
      message: 'Chat session cleared'
    });
  } catch (error) {
    logger.error('Clear chat session error:', error);
    res.status(500).json({
      success: false,
      error: {
        code: 'INTERNAL_ERROR',
        message: 'Failed to clear chat session'
      }
    });
  }
});

module.exports = router;
