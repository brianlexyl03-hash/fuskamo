const rateLimit = require('express-rate-limit');

// General API limiter — generous, just stops abuse.
const apiLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 300,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: true, message: 'Too many requests, please try again later.' },
});

// Tighter limiter for endpoints that cost real money per call (M-Pesa, AI).
const costlyEndpointLimiter = rateLimit({
  windowMs: 60 * 1000,
  limit: 10,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: true, message: 'Rate limit exceeded for this endpoint — slow down.' },
});

// Auth endpoints (token refresh) — tighter than the general limiter.
// Uncapped refresh attempts are a real brute-force/abuse surface even
// though Supabase validates the token itself; no reason to let someone
// hammer this endpoint at the general 300/15min rate.
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 20,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: true, message: 'Too many auth requests, please try again later.' },
});

module.exports = { apiLimiter, costlyEndpointLimiter, authLimiter };
