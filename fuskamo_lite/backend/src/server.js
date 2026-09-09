const app = require('./app');
const env = require('./config/env');
const logger = require('./utils/logger');
const { registerScheduledJobs } = require('./jobs/scheduledJobs');

// Express's own error middleware (middleware/errorHandler.js) only catches
// errors thrown inside a request's async chain via asyncHandler. Anything
// outside that — a bad Promise in a background job, a bug in
// registerScheduledJobs's own timers — previously crashed the process
// silently (or with just a raw Node stack trace to stdout, easy to miss
// in a hosted log stream). Log it loudly and exit deliberately instead of
// leaving the process in a possibly-corrupted state.
process.on('uncaughtException', (err) => {
  logger.error('uncaughtException — shutting down', err);
  process.exit(1);
});
process.on('unhandledRejection', (reason) => {
  logger.error('unhandledRejection — shutting down', reason);
  process.exit(1);
});

app.listen(env.port, () => {
  logger.info(`FUSKAMO backend listening on port ${env.port} (${env.nodeEnv})`);
  if (!env.isConfigured.supabase) logger.warn('Supabase admin client not configured — see backend/.env.example');
  if (!env.isConfigured.mpesa) logger.warn('M-Pesa not configured — see backend/.env.example');
  if (!env.isConfigured.ai) logger.warn('AI provider not configured — see backend/.env.example');

  registerScheduledJobs();
});
