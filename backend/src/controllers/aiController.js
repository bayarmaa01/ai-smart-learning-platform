const axios = require('axios');
const { v4: uuidv4 } = require('uuid');
const { query } = require('../db/connection');
const { getCache, setCache, incrementCounter } = require('../cache/redis');
const { AppError } = require('../middleware/errorHandler');
const { logger } = require('../utils/logger');

const AI_SERVICE_URL = process.env.AI_SERVICE_URL || 'http://localhost:8000';

const checkDailyLimit = async (userId, userPlan = 'free') => {
  const limits = { free: 10, basic: 50, pro: -1, enterprise: -1 };
  const limit = limits[userPlan] || 10;
  if (limit === -1) return true;

  const today = new Date().toISOString().split('T')[0];
  const key = `ai:daily:${userId}:${today}`;
  const count = await incrementCounter(key, 86400);
  return count <= limit;
};

const chat = async (req, res) => {
  const { message, session_id } = req.body;
  const userId = req.user.id;

  const withinLimit = await checkDailyLimit(userId, req.user.subscription_plan);
  if (!withinLimit) {
    throw new AppError('Daily AI chat limit reached. Upgrade your plan for unlimited access.', 429, 'AI_LIMIT_REACHED');
  }

  let sessionId = session_id;
  if (!sessionId) {
    sessionId = uuidv4();
    await query(
      'INSERT INTO ai_chat_sessions (user_id, session_id) VALUES ($1, $2) ON CONFLICT (session_id) DO NOTHING',
      [userId, sessionId]
    );
  }

  await query(
    `INSERT INTO ai_chat_messages (session_id, role, content) VALUES ($1, 'user', $2)`,
    [sessionId, message]
  );

  let aiResponse;
  try {
    const response = await axios.post(
      `${AI_SERVICE_URL}/chat`,
      {
        message,
        session_id: sessionId,
        user_id: userId,
        context: {
          user_role: req.user.role,
          language_preference: req.user.language_preference,
        },
      },
      { timeout: 30000 }
    );
    aiResponse = response.data;
  } catch (err) {
    logger.error('AI service error:', err.message);
    throw new AppError('AI service temporarily unavailable', 503, 'AI_SERVICE_ERROR');
  }

  await query(
    `INSERT INTO ai_chat_messages (session_id, role, content, detected_language, tokens_used)
     VALUES ($1, 'assistant', $2, $3, $4)`,
    [sessionId, aiResponse.response, aiResponse.detected_language, aiResponse.tokens_used || 0]
  );

  await query(
    `UPDATE ai_chat_sessions SET message_count = message_count + 2, last_message_at = NOW()
     WHERE session_id = $1`,
    [sessionId]
  );

  res.json({
    success: true,
    session_id: sessionId,
    response: aiResponse.response,
    detected_language: aiResponse.detected_language,
    sources: aiResponse.sources || [],
    message_id: uuidv4(),
  });
};

const getChatHistory = async (req, res) => {
  const { sessionId } = req.params;
  const userId = req.user.id;

  const sessionResult = await query(
    'SELECT id FROM ai_chat_sessions WHERE session_id = $1 AND user_id = $2',
    [sessionId, userId]
  );

  if (!sessionResult.rows.length) {
    throw new AppError('Session not found', 404, 'SESSION_NOT_FOUND');
  }

  const result = await query(
    `SELECT id, role, content, detected_language, created_at
     FROM ai_chat_messages WHERE session_id = $1 ORDER BY created_at ASC`,
    [sessionId]
  );

  res.json({ success: true, messages: result.rows });
};

const getRecommendations = async (req, res) => {
  const userId = req.user.id;

  const enrolledResult = await query(
    `SELECT c.category_id, c.level FROM enrollments e
     JOIN courses c ON e.course_id = c.id WHERE e.user_id = $1`,
    [userId]
  );

  const cacheKey = `recommendations:${userId}`;
  const cached = await getCache(cacheKey);
  if (cached) return res.json({ success: true, recommendations: cached });

  try {
    const response = await axios.post(`${AI_SERVICE_URL}/recommendations`, {
      user_id: userId,
      enrolled_courses: enrolledResult.rows,
      language_preference: req.user.language_preference,
    }, { timeout: 15000 });

    await setCache(cacheKey, response.data.recommendations, 3600);
    res.json({ success: true, recommendations: response.data.recommendations });
  } catch (err) {
    const fallback = await query(
      `SELECT id, title, thumbnail_url, rating_average, enrollment_count, price
       FROM courses WHERE status = 'published' ORDER BY rating_average DESC LIMIT 6`,
      []
    );
    res.json({ success: true, recommendations: fallback.rows });
  }
};

const clearSession = async (req, res) => {
  const { sessionId } = req.params;
  const userId = req.user.id;

  await query(
    'DELETE FROM ai_chat_sessions WHERE session_id = $1 AND user_id = $2',
    [sessionId, userId]
  );

  res.json({ success: true, message: 'Session cleared' });
};

module.exports = { chat, getChatHistory, getRecommendations, clearSession };
