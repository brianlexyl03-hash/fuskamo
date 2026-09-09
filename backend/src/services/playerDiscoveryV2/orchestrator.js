'use strict';

const { rankLightCandidates } = require('./lightRanker');
const { rankDeepCandidates } = require('./deepRanker');
const { rerankForDiversity, repetitionPenalty } = require('./diversity');
const { applyExploration } = require('./exploration');
const { applyBoostMixer } = require('./boostMixer');
const { applyFraudPenalty } = require('./fraudSignals');

function runPlayerDiscoveryV2({ scout, candidates, recentPlayerIds = [], subjectId, options = {} }) {
  const requestedLimit = Math.max(1, Math.min(Number(options.limit) || 30, 100));
  const light = rankLightCandidates(scout, candidates, { limit: options.lightLimit || 250, hardFraudThreshold: options.hardFraudThreshold });
  const deep = rankDeepCandidates(light, { model: options.model, modelOptions: options.modelOptions });

  const safetyAdjusted = deep.map((row) => ({
    ...row,
    deepScore: applyFraudPenalty(row.deepScore, row.player.fraud_score, { hardThreshold: options.hardFraudThreshold ?? 0.9 }),
  })).map((row) => ({
    ...row,
    deepScore: row.deepScore * repetitionPenalty(row.player, recentPlayerIds, options.recentLimit || 30),
  })).sort((a, b) => b.deepScore - a.deepScore || String(a.player.id).localeCompare(String(b.player.id)));

  const diversified = rerankForDiversity(safetyAdjusted, {
    limit: Math.min(requestedLimit * 3, safetyAdjusted.length),
    countryCap: options.countryCap || 3,
    clubCap: options.clubCap || 2,
  });
  const boosted = applyBoostMixer(diversified, { maxBoost: options.maxBoost ?? 0.15 });
  const explored = applyExploration(boosted, {
    limit: requestedLimit,
    rate: options.explorationRate ?? 0.12,
    subjectId,
    dateSalt: options.dateSalt,
  });

  return explored.map((row, index) => ({
    player: row.player,
    score: row.finalScore ?? row.deepScore,
    position: index + 1,
    model: options.model?.name || options.modelOptions?.name || 'player-discovery-utility',
    modelVersion: options.model?.version || options.modelOptions?.version || 'v2.0.0',
    exploration: Boolean(row.diversityScore !== undefined && !safetyAdjusted.slice(0, requestedLimit).includes(row)),
    objectives: row.prediction?.objectives || {},
  }));
}

module.exports = { runPlayerDiscoveryV2 };
