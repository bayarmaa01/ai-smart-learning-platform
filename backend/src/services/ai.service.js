const axios = require('axios');
const { logger } = require('../utils/logger');
const { getCache, setCache } = require('../cache/redis');

class AIService {
  constructor() {
    this.ollamaUrl = process.env.OLLAMA_URL || 'http://host.docker.internal:11434';
    this.model = process.env.OLLAMA_MODEL || 'gemma4:31b';
    this.timeout = 30000; // 30 seconds for larger model
    this.maxRetries = 3;
  }

  /**
   * Generate response from Ollama
   */
  async generate(prompt, options = {}) {
    const cacheKey = `ai:${this.model}:${Buffer.from(prompt).toString('base64').substring(0, 50)}`;
    
    try {
      // Check cache first
      const cached = await getCache(cacheKey);
      if (cached) {
        logger.info('AI response served from cache');
        return cached;
      }

      const response = await this.callOllama(prompt, options);
      
      // Cache the response for 1 hour
      await setCache(cacheKey, response, 3600);
      
      return response;
    } catch (error) {
      logger.error('AI Service Error:', error);
      throw error;
    }
  }

  /**
   * Call Ollama API with retries
   */
  async callOllama(prompt, options = {}) {
    const payload = {
      model: this.model,
      prompt: prompt,
      stream: false,
      options: {
        temperature: options.temperature || 0.7,
        top_p: options.top_p || 0.9,
        max_tokens: options.max_tokens || 1000
      }
    };

    let lastError;
    
    for (let attempt = 1; attempt <= this.maxRetries; attempt++) {
      try {
        logger.info(`AI Request attempt ${attempt}/${this.maxRetries}`);
        
        const response = await axios.post(`${this.ollamaUrl}/api/generate`, payload, {
          timeout: this.timeout,
          headers: {
            'Content-Type': 'application/json'
          }
        });

        if (response.data && response.data.response) {
          logger.info('AI response received successfully');
          return response.data.response;
        } else {
          throw new Error('Invalid response format from Ollama');
        }
      } catch (error) {
        lastError = error;
        logger.warn(`AI Request attempt ${attempt} failed:`, error.message);
        
        if (attempt < this.maxRetries) {
          // Exponential backoff
          const delay = Math.pow(2, attempt) * 1000;
          await this.sleep(delay);
        }
      }
    }
    
    throw new Error(`AI request failed after ${this.maxRetries} attempts: ${lastError.message}`);
  }

  /**
   * Sleep utility for retries
   */
  sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
  }

  /**
   * Health check for Ollama
   */
  async healthCheck() {
    try {
      const response = await axios.get(`${this.ollamaUrl}/api/tags`, {
        timeout: 5000
      });
      
      const hasGemma = response.data.models.some(model => 
        model.name.includes('gemma4') && model.name.includes('31b')
      );
      
      return {
        status: 'healthy',
        model: this.model,
        available: hasGemma,
        models: response.data.models
      };
    } catch (error) {
      return {
        status: 'unhealthy',
        error: error.message
      };
    }
  }
}

module.exports = new AIService();
