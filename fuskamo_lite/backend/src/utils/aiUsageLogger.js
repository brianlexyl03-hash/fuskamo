const { getSupabaseAdmin } = require('../config/supabase');
const modelRegistry = require('../ai/modelRegistry');
const logger = require('./logger');

/** Logs token usage + estimated cost per AI call to `ai_usage_logs`
 * (database/migrations/004_ai_usage_logs.sql) — this is what "cost
 * monitoring" actually means in practice: a queryable table you can sum. */
async function logAiUsage({ promptName, promptVersion, model, usage }) {
  const pricing = modelRegistry[model];
  const estimatedCost = pricing
    ? (usage.prompt_tokens / 1000) * pricing.inputPer1k + (usage.completion_tokens / 1000) * pricing.outputPer1k
    : null;

  logger.info(
    `AI usage: ${promptName}@${promptVersion} model=${model} tokens=${usage.total_tokens} est_cost=$${estimatedCost?.toFixed(5) ?? '?'}`
  );

  const client = getSupabaseAdmin();
  if (!client) return;
  const { error } = await client.from('ai_usage_logs').insert([{
    prompt_name: promptName,
    prompt_version: promptVersion,
    model,
    prompt_tokens: usage.prompt_tokens,
    completion_tokens: usage.completion_tokens,
    total_tokens: usage.total_tokens,
    estimated_cost_usd: estimatedCost,
  }]);
  if (error) logger.error('Failed to write ai_usage_logs row', error);
}

module.exports = { logAiUsage };
