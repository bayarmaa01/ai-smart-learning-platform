const axios = require('axios');
const { logger } = require('../utils/logger');

class OllamaService {
  constructor() {
    this.baseUrl = process.env.OLLAMA_BASE_URL || 'http://host.minikube.internal:11434';
    this.model = process.env.OLLAMA_MODEL || 'gemma4:31b';
    this.timeout = parseInt(process.env.OLLAMA_TIMEOUT) || 20000;
    this.maxRetries = parseInt(process.env.OLLAMA_MAX_RETRIES) || 3;
    this.retryDelay = parseInt(process.env.OLLAMA_RETRY_DELAY) || 1000;
  }

  async generateResponse(message, options = {}) {
    const startTime = Date.now();
    let lastError;

    logger.info(`AI request: ${message.substring(0, 100)}...`);

    for (let attempt = 1; attempt <= this.maxRetries; attempt++) {
      try {
        const response = await this.makeRequest(message, options);
        const duration = Date.now() - startTime;
        
        logger.info(`AI response received in ${duration}ms (attempt ${attempt})`);
        return response;
      } catch (error) {
        lastError = error;
        logger.warn(`AI request failed (attempt ${attempt}/${this.maxRetries}): ${error.message}`);
        
        if (attempt < this.maxRetries) {
          await this.delay(this.retryDelay * attempt);
        }
      }
    }

    logger.error(`AI request failed after ${this.maxRetries} attempts: ${lastError.message}`);
    return this.getFallbackResponse(message);
  }

  async makeRequest(message, options = {}) {
    const payload = {
      model: this.model,
      prompt: message,
      stream: false,
      options: {
        temperature: options.temperature || 0.7,
        top_p: options.top_p || 0.9,
        max_tokens: options.max_tokens || 1000,
        ...options
      }
    };

    try {
      const response = await axios.post(`${this.baseUrl}/api/generate`, payload, {
        timeout: this.timeout,
        headers: {
          'Content-Type': 'application/json'
        }
      });

      if (!response.data || !response.data.response) {
        throw new Error('Invalid response from Ollama');
      }

      return {
        success: true,
        response: response.data.response.trim(),
        model: this.model,
        tokens: response.data.eval_count || 0,
        duration: response.data.total_duration || 0
      };
    } catch (error) {
      if (error.code === 'ECONNABORTED') {
        throw new Error('Request timeout');
      }
      if (error.code === 'ECONNREFUSED') {
        throw new Error('Cannot connect to Ollama service');
      }
      if (error.response) {
        throw new Error(`Ollama error: ${error.response.status} ${error.response.statusText}`);
      }
      throw error;
    }
  }

  async checkHealth() {
    try {
      const response = await axios.get(`${this.baseUrl}/api/tags`, {
        timeout: 5000
      });

      const models = response.data.models || [];
      const hasModel = models.some(model => model.name === this.model);

      return {
        status: 'ok',
        baseUrl: this.baseUrl,
        model: this.model,
        available: hasModel,
        totalModels: models.length,
        models: models.map(m => m.name)
      };
    } catch (error) {
      logger.error(`Ollama health check failed: ${error.message}`);
      return {
        status: 'error',
        error: error.message,
        baseUrl: this.baseUrl,
        model: this.model
      };
    }
  }

  getFallbackResponse(message) {
    const fallbacks = [
      "I'm having trouble connecting to my AI services right now. Please try again in a moment.",
      "I apologize, but I'm experiencing technical difficulties. Please try again later.",
      "My AI capabilities are temporarily unavailable. Please try again shortly.",
      "I'm unable to process your request at the moment. Please try again."
    ];

    return {
      success: false,
      response: fallbacks[Math.floor(Math.random() * fallbacks.length)],
      model: this.model,
      fallback: true
    };
  }

  delay(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
  }
}

module.exports = new OllamaService();
