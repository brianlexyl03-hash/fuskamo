const rateLimit = require('express-rate-limit');

/**
 * Admin endpoints see far less legitimate traffic than the public API, so
 * they get tighter limits than middleware/rateLimiter.js's general
 * apiLimiter — this is on top of it, not instead of it (both apply, see
 * app.js). Keyed by IP by default; if this backend runs behind multiple
 * instances, point these at Redis (ioredis is already a dependency — see
 * env.redis.url) via rate-limit-redis instead of the in-memory default
 * before scaling past one instance, or each instance enforces its own
 * separate window.
 */

// Approve/reject/refund/etc — real admin actions, not just reads.
const adminActionLimiter = rateLimit({
  windowMs: 60 * 1000,
  limit: 30,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: true, message: 'Too many admin actions in a short window — slow down.' },
});

// Creating/disabling/suspending/revoking other admin accounts — the most
// sensitive surface in the system, deliberately the tightest limit.
const adminAccountLimiter = rateLimit({
  windowMs: 60 * 60 * 1000,
  limit: 20,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: true, message: 'Too many admin-account changes this hour — slow down.' },
});

// Session-management endpoints (list/revoke sessions) — moderate.
const adminSessionLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 40,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: true, message: 'Too many session-management requests — slow down.' },
});

module.exports = { adminActionLimiter, adminAccountLimiter, adminSessionLimiter };
