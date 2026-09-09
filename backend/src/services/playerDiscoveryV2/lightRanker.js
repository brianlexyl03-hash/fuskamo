'use strict';

const { clamp } = require('./fraudSignals');

function logSignal(value, scale = 1) {
  return clamp(Math.log1p(Math.max(0, Number(value) || 0)) / scale);
}

function buildFeatures(scout, player) {
  const positions = scout?.preferred_positions || [];
  const countries = scout?.preferred_countries || [];
  const ageMin = scout?.age_min;
  const ageMax = scout?.age_max;
  const ageMatch = (ageMin == null || player.age >= ageMin) && (ageMax == null || player.age <= ageMax);
  const position = positions.length ? (positions.includes(player.position) ? 1 : 0) : 0.5;
  const country = countries.length ? (countries.includes(player.country) ? 1 : 0) : 0.5;
  const foot = scout?.preferred_foot && player.foot ? (scout.preferred_foot === player.foot || player.foot === 'both' ? 1 : 0) : 0.5;
  const height = scout?.preferred_height_min != null && player.height != null
    ? clamp((player.height - scout.preferred_height_min + 20) / 40)
    : 0.5;

  const match = position * 0.42 + country * 0.16 + (ageMatch ? 0.18 : 0) + foot * 0.12 + height * 0.12;
  const engagement = logSignal(player.views_7d, 8) * 0.25 + logSignal(player.saves_7d, 4) * 0.35 + logSignal(player.contacts_7d, 2) * 0.30 + logSignal(player.shares_7d, 3) * 0.10;
  const trust = clamp((Number(player.trust_score) || 0) / 100);
  const quality = clamp(player.quality_score);
  const completeness = clamp(player.profile_completeness);
  const potential = clamp(0.55 * completeness + 0.25 * (Number(player.achievement_count) > 0 ? Math.min(1, player.achievement_count / 10) : 0) + 0.20 * trust);
  const freshness = clamp(1 - Math.max(0, (Date.now() - new Date(player.created_at || Date.now()).getTime()) / 86400000) / 30);
  const conversion = clamp(logSignal(player.saves_7d, 3) * 0.6 + logSignal(player.contacts_7d, 2) * 0.4);
  const safety = 1 - clamp(player.fraud_score);

  return {
    match: clamp(match), quality, engagement, trust, freshness, potential, conversion, safety,
    completeness,
  };
}

function lightScore(features) {
  return clamp(
    features.match * 0.34 +
    features.quality * 0.22 +
    features.engagement * 0.18 +
    features.trust * 0.10 +
    features.freshness * 0.08 +
    features.safety * 0.08
  );
}

function rankLightCandidates(scout, players, options = {}) {
  const limit = Math.max(1, Math.min(Number(options.limit) || 200, 1000));
  return (players || [])
    .filter((p) => p.status === 'approved' && Number(p.fraud_score || 0) < (options.hardFraudThreshold ?? 0.9))
    .map((player) => {
      const features = buildFeatures(scout, player);
      return { player, features, lightScore: lightScore(features) };
    })
    .sort((a, b) => b.lightScore - a.lightScore || String(a.player.id).localeCompare(String(b.player.id)))
    .slice(0, limit);
}

module.exports = { buildFeatures, lightScore, rankLightCandidates };
