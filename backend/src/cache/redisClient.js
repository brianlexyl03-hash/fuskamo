const Redis = require('ioredis');
const env = require('../config/env');
const logger = require('../utils/logger');

/**
 * Optional Redis cache — falls back to simpleCache.js (in-process NodeCache)
 * when REDIS_URL isn't set, so the app works with zero extra infra locally
 * and gains shared/persistent caching once you add a Redis instance (most
 * hosts offer a free small tier: Upstash, Redis Cloud).
 */
let client = null;

function getRedis() {
  if (client) return client;
  if (!env.isConfigured.redis) return null;
  client = new Redis(env.redis.url);
  client.on('error', (err) => logger.error('Redis connection error', err));
  return client;
}

module.exports = { getRedis };
