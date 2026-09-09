const mpesaService = require('./mpesaService');
const transactionRepository = require('../repositories/transactionRepository');
const logger = require('../utils/logger');

/**
 * Catches payments whose callback never arrived (webhooks do get dropped
 * on real networks). Run periodically (see jobs/scheduledJobs.js) — finds
 * transactions stuck 'pending' past a threshold and actively queries
 * Safaricom for the real status instead of waiting forever.
 */
async function reconcilePendingTransactions({ olderThanMinutes = 10 } = {}) {
  const stuck = await transactionRepository.listPendingOlderThan(olderThanMinutes);
  let reconciled = 0;

  for (const txn of stuck) {
    try {
      const result = await mpesaService.queryStkPushStatus(txn.checkout_request_id);
      const success = result.ResultCode === '0' || result.ResultCode === 0;
      await transactionRepository.finalize(txn.checkout_request_id, {
        status: success ? 'completed' : 'failed',
        mpesaReceiptNumber: null, // not returned by the query endpoint, only by the callback
        resultDesc: result.ResultDesc,
      });
      reconciled++;
    } catch (err) {
      logger.error(`Reconciliation failed for ${txn.checkout_request_id}`, err);
    }
  }

  logger.info(`Reconciliation run: ${reconciled}/${stuck.length} stuck transactions resolved`);
  return { checked: stuck.length, reconciled };
}

module.exports = { reconcilePendingTransactions };
