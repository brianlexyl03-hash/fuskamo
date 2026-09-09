'use strict';

const { clamp } = require('./fraudSignals');

function applyBoostMixer(rows, options = {}) {
  const maxBoost = Number(options.maxBoost ?? 0.15);
  const now = Date.now();
  return (rows || []).map((row) => {
    const featuredUntil = row.player.featured_until ? new Date(row.player.featured_until).getTime() : 0;
    const active = featuredUntil > now;
    const trust = clamp((Number(row.player.trust_score) || 0) / 100);
    const boost = active ? maxBoost * (0.65 + trust * 0.35) : 0;
    return { ...row, boostScore: boost, finalScore: clamp(row.deepScore * (1 + boost)) };
  }).sort((a, b) => b.finalScore - a.finalScore || String(a.player.id).localeCompare(String(b.player.id)));
}

module.exports = { applyBoostMixer };
