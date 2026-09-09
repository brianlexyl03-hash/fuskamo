/**
 * Generic exponential-backoff retry for any async operation — used for
 * flaky-but-idempotent calls (M-Pesa status queries, AI provider calls).
 * NOT used for the STK push initiation itself (retrying that could trigger
 * two PIN prompts on the payer's phone) — see mpesaService for where retry
 * is and isn't appropriate.
 */
async function retry(fn, { attempts = 3, baseDelayMs = 500 } = {}) {
  let lastErr;
  for (let i = 0; i < attempts; i++) {
    try {
      return await fn();
    } catch (err) {
      lastErr = err;
      if (i < attempts - 1) {
        await new Promise((r) => setTimeout(r, baseDelayMs * Math.pow(2, i)));
      }
    }
  }
  throw lastErr;
}

module.exports = { retry };
