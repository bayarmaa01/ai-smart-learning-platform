const aiService = require('../services/ai.service');
const { logger } = require('../utils/logger');

class AIController {
  /**
   * AI Tutor - Explain topics like a teacher
   */
  static async tutor(req, res) {
    try {
      const { question } = req.body;
      
      if (!question) {
        return res.status(400).json({
          success: false,
          error: 'Question is required'
        });
      }

      const prompt = `You are an expert teacher explaining concepts to beginner students. 
Explain the topic: "${question}"

Provide:
1. A simple, clear explanation
2. Step-by-step breakdown
3. Beginner-friendly tone
4. One real-world example
5. Keep it concise but comprehensive

Format your response as clean JSON:
{
  "explanation": "detailed explanation",
  "steps": ["step1", "step2", "step3"],
  "example": "real-world example",
  "difficulty": "beginner|intermediate|advanced"
}`;

      const response = await aiService.generate(prompt);
      
      // Try to parse as JSON, fallback to text
      let result;
      try {
        result = JSON.parse(response);
      } catch (e) {
        result = {
          explanation: response,
          steps: [],
          example: '',
          difficulty: 'beginner'
        };
      }

      res.json({
        success: true,
        data: result
      });

    } catch (error) {
      logger.error('AI Tutor Error:', error);
      res.status(500).json({
        success: false,
        error: 'Failed to generate explanation',
        fallback: 'Please try again later'
      });
    }
  }

  /**
   * AI Quiz Generator - Generate multiple choice questions
   */
  static async quiz(req, res) {
    try {
      const { topic } = req.body;
      
      if (!topic) {
        return res.status(400).json({
          success: false,
          error: 'Topic is required'
        });
      }

      const prompt = `Generate 5 multiple choice questions about: "${topic}"

For each question provide:
1. Clear question text
2. 4 options (A, B, C, D)
3. Correct answer letter
4. Brief explanation

Format as JSON:
{
  "quiz": [
    {
      "question": "question text",
      "options": {
        "A": "option A",
        "B": "option B", 
        "C": "option C",
        "D": "option D"
      },
      "correct_answer": "A",
      "explanation": "brief explanation"
    }
  ]
}`;

      const response = await aiService.generate(prompt);
      
      let result;
      try {
        result = JSON.parse(response);
      } catch (e) {
        result = {
          quiz: [],
          error: 'Failed to parse quiz format'
        };
      }

      res.json({
        success: true,
        data: result
      });

    } catch (error) {
      logger.error('AI Quiz Error:', error);
      res.status(500).json({
        success: false,
        error: 'Failed to generate quiz',
        fallback: 'Please try again later'
      });
    }
  }

  /**
   * AI Smart Explanation - Topic explanations with examples
   */
  static async explain(req, res) {
    try {
      const { topic } = req.body;
      
      if (!topic) {
        return res.status(400).json({
          success: false,
          error: 'Topic is required'
        });
      }

      const prompt = `Explain "${topic}" in a smart, practical way.

Provide:
1. Short, clear explanation (2-3 sentences)
2. When to use it (practical scenarios)
3. Real-world example
4. Key benefits

Format as JSON:
{
  "explanation": "concise explanation",
  "when_to_use": ["scenario1", "scenario2"],
  "example": "real-world example",
  "benefits": ["benefit1", "benefit2"]
}`;

      const response = await aiService.generate(prompt);
      
      let result;
      try {
        result = JSON.parse(response);
      } catch (e) {
        result = {
          explanation: response,
          when_to_use: [],
          example: '',
          benefits: []
        };
      }

      res.json({
        success: true,
        data: result
      });

    } catch (error) {
      logger.error('AI Explain Error:', error);
      res.status(500).json({
        success: false,
        error: 'Failed to generate explanation',
        fallback: 'Please try again later'
      });
    }
  }

  /**
   * AI Error Helper - Debug DevOps issues
   */
  static async debug(req, res) {
    try {
      const { error } = req.body;
      
      if (!error) {
        return res.status(400).json({
          success: false,
          error: 'Error description is required'
        });
      }

      const prompt = `You are a senior DevOps engineer debugging infrastructure issues.

Analyze this error: "${error}"

Provide:
1. Root cause analysis
2. Step-by-step fix instructions
3. Prevention measures
4. Related commands to run

Format as JSON:
{
  "root_cause": "analysis of what went wrong",
  "fix_steps": ["step1", "step2", "step3"],
  "prevention": ["tip1", "tip2"],
  "commands": ["command1", "command2"],
  "severity": "low|medium|high|critical"
}`;

      const response = await aiService.generate(prompt);
      
      let result;
      try {
        result = JSON.parse(response);
      } catch (e) {
        result = {
          root_cause: response,
          fix_steps: [],
          prevention: [],
          commands: [],
          severity: 'medium'
        };
      }

      res.json({
        success: true,
        data: result
      });

    } catch (error) {
      logger.error('AI Debug Error:', error);
      res.status(500).json({
        success: false,
        error: 'Failed to analyze error',
        fallback: 'Check logs and verify configuration'
      });
    }
  }

  /**
   * AI Chat - General chat interface
   */
  static async chat(req, res) {
    try {
      const { message } = req.body;
      
      if (!message) {
        return res.status(400).json({
          success: false,
          error: 'Message is required'
        });
      }

      const prompt = `You are a helpful AI learning assistant. Respond to this user message in a friendly, educational way: "${message}"

Provide a helpful, concise response that:
1. Directly answers their question
2. Is educational and supportive
3. Keeps it conversational and friendly
4. Is appropriate for a learning platform

Format your response as JSON:
{
  "response": "your helpful response",
  "type": "answer|explanation|guidance"
}`;

      const response = await aiService.generate(prompt);
      
      let result;
      try {
        result = JSON.parse(response);
      } catch (e) {
        result = {
          response: response,
          type: 'answer'
        };
      }

      res.json({
        success: true,
        data: result
      });

    } catch (error) {
      logger.error('AI Chat Error:', error);
      res.status(500).json({
        success: false,
        error: 'Failed to process chat message',
        fallback: 'I apologize, but I\'m having trouble processing your message right now. Please try again.'
      });
    }
  }

  /**
   * AI Health Check
   */
  static async health(req, res) {
    try {
      const health = await aiService.healthCheck();
      
      res.json({
        success: true,
        data: {
          ai_service: health,
          timestamp: new Date().toISOString()
        }
      });

    } catch (error) {
      logger.error('AI Health Check Error:', error);
      res.status(500).json({
        success: false,
        error: 'AI service health check failed'
      });
    }
  }
}

module.exports = AIController;
