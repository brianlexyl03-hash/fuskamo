const express = require('express');
const router = express.Router();
const axios = require('axios');
const env = require('../config/env');
const asyncHandler = require('../utils/asyncHandler');
const AppError = require('../errors/AppError');
const { authLimiter } = require('../middleware/rateLimiter');

/**
 * Thin proxy to Supabase Auth's own refresh-token endpoint. Supabase
 * already implements refresh token rotation correctly — this exists only
 * so the Flutter app has one consistent backend host to talk to, and so a
 * future switch away from Supabase Auth doesn't change the app's API
 * surface. If the app uses supabase_flutter's own auth client directly,
 * this endpoint isn't even needed — kept for completeness since it was
 * explicitly requested.
 */
router.post('/refresh', authLimiter, asyncHandler(async (req, res) => {
  const { refreshToken } = req.body;
  if (!refreshToken) throw new AppError('refreshToken is required', 400);
  if (!env.isConfigured.supabase) throw new AppError('Supabase not configured', 503);

  const { data } = await axios.post(
    `${env.supabase.url}/auth/v1/token?grant_type=refresh_token`,
    { refresh_token: refreshToken },
    { headers: { apikey: env.supabase.serviceRoleKey } }
  );
  res.status(200).json({ success: true, data });
}));

module.exports = router;
