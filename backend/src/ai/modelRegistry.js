/** Approximate USD cost per 1K tokens — update as providers change pricing.
 * Used only for the cost-monitoring estimate in aiService, not billing. */
module.exports = {
  'gpt-4o-mini': { inputPer1k: 0.00015, outputPer1k: 0.0006, provider: 'openai' },
  'gpt-4o': { inputPer1k: 0.0025, outputPer1k: 0.01, provider: 'openai' },
  'claude-haiku-4-5-20251001': { inputPer1k: 0.001, outputPer1k: 0.005, provider: 'anthropic' },
};
