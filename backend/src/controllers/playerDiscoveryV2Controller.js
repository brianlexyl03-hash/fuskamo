'use strict';

const crypto = require('node:crypto');
const repo = require('../repositories/playerDiscoveryV2Repository');
const { runPlayerDiscoveryV2 } = require('../services/playerDiscoveryV2/orchestrator');
const { createHeuristicModel } = require('../services/playerDiscoveryV2/modelInterface');
const asyncHandler = require('../utils/asyncHandler');
const AppError = require('../errors/AppError');

const VALID_EVENT_TYPES = ['view', 'save', 'contact', 'share', 'skip', 'hide', 'report'];

function hash(value) { return crypto.createHash('sha256').update(String(value)).digest('hex'); }

exports.getFeed = asyncHandler(async (req, res) => {
  const scout = await repo.getScoutForUser(req.user.id);
  if (!scout) throw new AppError('No verified scout profile for this account', 404);
  const limit = Math.min(Math.max(Number.parseInt(req.query.limit, 10) || 30, 1), 100);
  const candidates = await repo.getCandidatePlayers(req.user.id);
  const recent = await repo.getRecentPlayerIds(req.user.id, 50);
  const model = createHeuristicModel();
  const results = runPlayerDiscoveryV2({
    scout, candidates, recentPlayerIds: recent, subjectId: req.user.id,
    options: { limit, model, explorationRate: 0.12, countryCap: 3, clubCap: 2 },
  });
  // Impression logging is best-effort: a feed should remain available even if
  // analytics is temporarily unavailable.
  try { await repo.recordImpressions({ subjectId: req.user.id, rows: results }); } catch (_) { /* intentional */ }
  res.status(200).json({ success: true, data: results });
});

exports.logEvent = asyncHandler(async (req, res) => {
  const { playerId, eventType, deviceId, metadata } = req.body || {};
  if (!playerId || typeof playerId !== 'string') throw new AppError('playerId is required', 400);
  if (!VALID_EVENT_TYPES.includes(eventType)) throw new AppError(`eventType must be one of: ${VALID_EVENT_TYPES.join(', ')}`, 400);
  const ip = req.ip || req.headers['x-forwarded-for'];
  await repo.logEvent({ playerId, actorId: req.user.id, eventType, ipHash: ip ? hash(ip) : null, deviceHash: deviceId ? hash(deviceId) : null, metadata: metadata && typeof metadata === 'object' ? metadata : {} });
  res.status(201).json({ success: true });
});

exports.runFraudRecompute = async () => repo.recomputeFraudSignals();
