const { Queue } = require('bullmq');
const { getRedis } = require('../cache/redisClient');
const env = require('../config/env');

/**
 * BullMQ needs Redis — if REDIS_URL isn't set, queue operations no-op with
 * a warning rather than crashing the whole server, so the app still runs
 * without a queue in local/dev.
 */
let aiSummaryQueue = null;

function getAiSummaryQueue() {
  if (aiSummaryQueue) return aiSummaryQueue;
  if (!env.isConfigured.redis) return null;
  aiSummaryQueue = new Queue('ai-summary', { connection: { url: env.redis.url } });
  return aiSummaryQueue;
}

module.exports = { getAiSummaryQueue };
