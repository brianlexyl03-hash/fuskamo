const axios = require('axios');
const env = require('../config/env');
const AppError = require('../errors/AppError');
const promptTemplates = require('../ai/promptTemplates');
const { logAiUsage } = require('../utils/aiUsageLogger');
const { retry } = require('../utils/retry');
const logger = require('../utils/logger');

/**
 * Wraps any OpenAI-compatible chat completions API, with:
 * - multi-model support (pass `model` to override env.ai.model per call)
 * - a fallback provider if the primary fails
 * - token usage + cost logging on every call
 * - conversation history support (optional, for future multi-turn features)
 */
class AiService {
  _assertConfigured() {
    if (!env.isConfigured.ai) {
      throw new AppError('AI provider is not configured on this server yet — see backend/.env.example', 503);
    }
  }

  async _callProvider({ baseUrl, apiKey, model, messages }) {
    const { data } = await axios.post(
      `${baseUrl}/chat/completions`,
      { model, messages, max_tokens: 200, temperature: 0.4 },
      { headers: { Authorization: `Bearer ${apiKey}` } }
    );
    return data;
  }

  /** conversationHistory: optional array of prior {role, content} messages,
   * so a caller can build multi-turn AI features later without changing
   * this method's shape. */
  async generatePlayerSummary({ name, position, age, country, club, strengths, conversationHistory = [] }) {
    this._assertConfigured();
    const template = promptTemplates.playerSummary;
    const prompt = template.build({ name, position, age, country, club, strengths });
    const messages = [...conversationHistory, { role: 'user', content: prompt }];

    let data;
    try {
      data = await retry(
        () => this._callProvider({ baseUrl: env.ai.baseUrl, apiKey: env.ai.apiKey, model: env.ai.model, messages }),
        { attempts: 2 }
      );
    } catch (primaryErr) {
      if (!env.ai.fallbackBaseUrl || !env.ai.fallbackApiKey) throw primaryErr;
      logger.warn('Primary AI provider failed, falling back to secondary provider');
      data = await this._callProvider({
        baseUrl: env.ai.fallbackBaseUrl,
        apiKey: env.ai.fallbackApiKey,
        model: env.ai.fallbackModel,
        messages,
      });
    }

    if (data.usage) {
      await logAiUsage({
        promptName: 'playerSummary',
        promptVersion: template.version,
        model: env.ai.model,
        usage: data.usage,
      });
    }

    return data.choices?.[0]?.message?.content?.trim() || '';
  }
}

module.exports = new AiService();
