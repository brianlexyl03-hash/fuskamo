const env = require('../config/env');
const AppError = require('../errors/AppError');
const { verifySupabaseJwt } = require('./verifySupabaseJwt');

/**
 * Verifies Supabase Auth JWTs (Phase 2 user auth, once wired up client-side).
 * Supabase signs user session tokens with SUPABASE_JWT_SECRET (Project
 * Settings → API → JWT Secret) — this middleware validates that signature
 * and attaches the decoded claims to req.user.
 *
 * Distinct from authentication/apiKeyAuth.js (a single shared app secret) —
 * this is per-user identity, for endpoints that need to know WHO is calling,
 * not just THAT it's the real app.
 */
module.exports = async function jwtAuth(req, res, next) {
  const header = req.header('authorization') || '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : null;
  if (!token) return next(new AppError('Missing bearer token', 401));

  try {
    const decoded = await verifySupabaseJwt(token);
    req.user = { id: decoded.sub, role: decoded.role || 'authenticated', claims: decoded };
    next();
  } catch (e) {
    return next(new AppError('Invalid or expired token', 401));
  }
};
