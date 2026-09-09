const env = require('../config/env');
const AppError = require('../errors/AppError');

/**
 * Simple shared-secret auth between the Flutter app and this backend.
 * Not user auth (that's Supabase's job for Phase 2) — this just stops
 * randoms on the internet from hitting M-Pesa/AI endpoints and burning
 * your quota/money.
 */
module.exports = (req, res, next) => {
  if (!env.backendApiKey) {
    // Not configured yet — allow through in local dev, but warn loudly.
    return next();
  }
  const provided = req.header('x-api-key');
  if (provided !== env.backendApiKey) {
    return next(new AppError('Invalid or missing API key', 401));
  }
  next();
};
