const axios = require('axios');
const { logger } = require('../utils/logger');
const { getCache, setCache } = require('../cache/redis');

class AIService {
  constructor() {
    this.ollamaUrls = this.buildOllamaUrls();
    this.ollamaUrl = this.ollamaUrls[0];
    this.model = process.env.OLLAMA_MODEL || 'gemma4:31b';
    this.timeout = 30000; // 30 seconds for larger model
    this.maxRetries = 3;
  }

  buildOllamaUrls() {
    const primary = process.env.OLLAMA_URL || 'http://host.minikube.internal:11434';
    const fallbackRaw = process.env.OLLAMA_FALLBACK_URLS || '';
    const urls = [primary, ...fallbackRaw.split(',')]
      .map((url) => url.trim())
      .filter(Boolean);
    return [...new Set(urls)];
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
    
    for (const baseUrl of this.ollamaUrls) {
      for (let attempt = 1; attempt <= this.maxRetries; attempt++) {
        try {
          logger.info(`AI Request to ${baseUrl} attempt ${attempt}/${this.maxRetries}`);

          const response = await axios.post(`${baseUrl}/api/generate`, payload, {
            timeout: this.timeout,
            headers: {
              'Content-Type': 'application/json',
            },
          });

          if (response.data && response.data.response) {
            logger.info(`AI response received successfully from ${baseUrl}`);
            return response.data.response;
          }

          throw new Error('Invalid response format from Ollama');
        } catch (error) {
          lastError = error;
          logger.warn(`AI Request to ${baseUrl} attempt ${attempt} failed:`, error.message);

          if (attempt < this.maxRetries) {
            const delay = Math.pow(2, attempt) * 1000;
            await this.sleep(delay);
          }
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
    for (const baseUrl of this.ollamaUrls) {
      try {
        const response = await axios.get(`${baseUrl}/api/tags`, {
          timeout: 5000,
        });

        const hasGemma = response.data.models.some((model) =>
          model.name.includes('gemma4') && model.name.includes('31b')
        );

        return {
          status: 'healthy',
          endpoint: baseUrl,
          model: this.model,
          available: hasGemma,
          models: response.data.models,
        };
      } catch (error) {
        logger.warn(`AI health check failed for ${baseUrl}: ${error.message}`);
      }
    }
    return {
      status: 'unhealthy',
      error: 'All configured Ollama endpoints are unreachable',
    };
  }
}

module.exports = new AIService();
