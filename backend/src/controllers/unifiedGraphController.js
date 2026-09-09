'use strict';
const asyncHandler = require('../utils/asyncHandler');
const AppError = require('../errors/AppError');
const repo = require('../repositories/unifiedGraphRepository');
const engine = require('../services/unifiedGraphEngine');

exports.getFeed = asyncHandler(async (req, res) => {
  const limit = Math.min(Math.max(parseInt(req.query.limit, 10) || 30, 1), 100);
  const [candidates, following, negatives] = await Promise.all([
    repo.getCandidates(400),
    repo.getFollowing(req.user.id),
    repo.getNegativeSignals(req.user.id),
  ]);
  const ranked = engine.rankCandidates(candidates, {
    following,
    negativeByAuthor: negatives.negative,
    reportPenaltyByAuthor: negatives.reports,
    preferredRoles: req.user.role_preferences || [],
  }, limit);
  await repo.recordImpressions(req.user.id, ranked);
  res.json({ success: true, model_version: engine.MODEL_VERSION, data: ranked.map((entry) => ({ ...entry.candidate, ...engine.explain(entry) })) });
});

exports.event = asyncHandler(async (req, res) => {
  const { objectType, objectId, eventType, subjectUserId, sessionId, metadata } = req.body || {};
  if (!objectType || !objectId || !eventType) throw new AppError('objectType, objectId and eventType are required', 400);
  await repo.recordEvent({ userId: req.user.id, objectType, objectId, eventType, subjectUserId, sessionId, metadata });
  res.status(201).json({ success: true });
});
