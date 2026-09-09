const { Worker } = require('bullmq');
const env = require('../config/env');
const aiService = require('../services/aiService');
const playerAdminRepository = require('../repositories/playerAdminRepository');
const logger = require('../utils/logger');

/**
 * Runs as a SEPARATE process from the API server (`npm run worker`), so a
 * slow AI call never blocks a request thread. Processes jobs pushed by
 * jobs/queue.js — e.g. generating a summary for every new submission
 * asynchronously instead of making the submitter's request wait on it.
 */
if (!env.isConfigured.redis) {
  logger.warn('REDIS_URL not set — worker has nothing to connect to. Exiting.');
  process.exit(0);
}

const worker = new Worker(
  'ai-summary',
  async (job) => {
    const { playerId, name, position, age, country, club, strengths } = job.data;
    const summary = await aiService.generatePlayerSummary({ name, position, age, country, club, strengths });
    logger.info(`Generated AI summary for player ${playerId}`);
    return { playerId, summary };
  },
  { connection: { url: env.redis.url } }
);

worker.on('failed', (job, err) => logger.error(`Job ${job?.id} failed`, err));
logger.info('AI summary worker started, listening for jobs.');
