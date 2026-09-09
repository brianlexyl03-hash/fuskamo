const cron = require('node-cron');
const { reconcilePendingTransactions } = require('../services/reconciliationService');
const playerAdminRepository = require('../repositories/playerAdminRepository');
const discoveryRepository = require('../repositories/discoveryRepository');
const { getSupabaseAdmin } = require('../config/supabase');
const logger = require('../utils/logger');

/**
 * Registered from server.js. Runs in the SAME process as the API server —
 * fine at this scale; if jobs ever get heavy/slow, move them into
 * jobs/worker.js (BullMQ) instead so they don't compete with request
 * handling.
 */
function registerScheduledJobs() {
  // Every 10 minutes: resolve M-Pesa payments whose callback never arrived.
  cron.schedule('*/10 * * * *', async () => {
    try {
      await reconcilePendingTransactions({ olderThanMinutes: 10 });
    } catch (err) {
      logger.error('Scheduled reconciliation failed', err);
    }
  });

  // Daily at 03:00: clean up player submissions left 'pending' for 90+ days
  // (never reviewed) — keeps the moderation queue meaningful. Does NOT
  // delete approved/rejected rows, only stale untouched pending ones.
  cron.schedule('0 3 * * *', async () => {
    const client = getSupabaseAdmin();
    if (!client) return;
    const cutoff = new Date(Date.now() - 90 * 24 * 60 * 60 * 1000).toISOString();
    const { error, count } = await client
      .from('players')
      .delete({ count: 'exact' })
      .eq('status', 'pending')
      .lt('created_at', cutoff);
    if (error) logger.error('Daily cleanup job failed', error);
    else logger.info(`Daily cleanup: removed ${count ?? 0} stale pending submissions`);
  });

  // Daily: remove expired verification ticks; expired identities require re-review.
  cron.schedule('15 2 * * *', async () => {
    const client = getSupabaseAdmin();
    if (!client) return;
    try {
      await client.rpc('expire_verification_badges');
    } catch (error) {
      logger.error('expire_verification_badges failed', error);
    }
  });

  // Hourly: recompute players.fraud_score from 7-day player_events IP/device
  // concentration. Feeds discoveryEngine.js's eligibility filter and score
  // penalty — see discoveryRepository.recomputeFraudScores().
  cron.schedule('0 * * * *', async () => {
    try {
      const { updated } = await discoveryRepository.recomputeFraudScores();
      logger.info(`Discovery fraud recompute: updated ${updated} player(s).`);
    } catch (err) {
      logger.error('Scheduled fraud recompute failed', err);
    }
  });

  logger.info(
    'Scheduled jobs registered (reconciliation every 10min, verification expiry daily 02:15, cleanup daily 03:00, fraud recompute hourly).'
  );
}

module.exports = { registerScheduledJobs };
