'use strict';

const crypto = require('crypto');
const discoveryRepository = require('../repositories/discoveryRepository');
const discoveryEngine = require('../services/discoveryEngine');
const asyncHandler = require('../utils/asyncHandler');
const AppError = require('../errors/AppError');
const logger = require('../utils/logger');

const VALID_EVENT_TYPES = ['view', 'save', 'contact', 'share'];
const DEFAULT_LIMIT = 30;
const MAX_LIMIT = 100;

function hash(value) {
  return crypto.createHash('sha256').update(String(value)).digest('hex');
}

// GET /api/discovery/feed?limit=30
// Requires jwtAuth — req.user.id is the signed-in scout's auth.users id.
exports.getFeed = asyncHandler(async (req, res) => {
  const scout = await discoveryRepository.getScoutForUser(req.user.id);
  if (!scout) {
    throw new AppError('No verified scout profile for this account', 404);
  }

  const candidates = await discoveryRepository.getEligiblePlayers();
  const ranked = discoveryEngine.rankPlayers(scout, candidates);

  const requested = parseInt(req.query.limit, 10);
  const limit = Number.isFinite(requested) ? Math.min(Math.max(requested, 1), MAX_LIMIT) : DEFAULT_LIMIT;

  res.status(200).json({
    success: true,
    data: ranked.slice(0, limit).map((r) => ({
      player: r.player,
      score: Math.round(r.score * 100) / 100,
    })),
  });
});

// POST /api/discovery/events  { playerId, eventType, deviceId? }
// Requires jwtAuth. IP/device are hashed here, server-side — the client
// never gets to assert its own fraud-relevant identifiers directly.
exports.logEvent = asyncHandler(async (req, res) => {
  const { playerId, eventType, deviceId } = req.body || {};

  if (!playerId || typeof playerId !== 'string') {
    throw new AppError('playerId is required', 400);
  }
  if (!VALID_EVENT_TYPES.includes(eventType)) {
    throw new AppError(`eventType must be one of: ${VALID_EVENT_TYPES.join(', ')}`, 400);
  }

  const ip = req.ip || req.headers['x-forwarded-for'];
  const ipHash = ip ? hash(ip) : null;
  const deviceHash = deviceId ? hash(deviceId) : null;

  await discoveryRepository.logEvent({
    playerId,
    actorId: req.user.id,
    eventType,
    ipHash,
    deviceHash,
  });

  res.status(201).json({ success: true });
});

// Internal — invoked by scheduledJobs.js, not exposed as a route.
exports.runFraudRecompute = async () => {
  const result = await discoveryRepository.recomputeFraudScores();
  logger.info(`Discovery fraud recompute: updated ${result.updated} player(s).`);
  return result;
};
