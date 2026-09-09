'use strict';

function clamp(value, min = 0, max = 1) {
  const n = Number(value);
  return Number.isFinite(n) ? Math.max(min, Math.min(max, n)) : min;
}

function ratio(a, b) {
  const denominator = Number(b) || 0;
  return denominator > 0 ? clamp(Number(a) / denominator) : 0;
}

/**
 * Converts raw 7-day player event aggregates into bounded fraud/risk signals.
 * This is intentionally conservative: high risk can suppress ranking, but a
 * single weak signal cannot prove abuse by itself.
 */
function computeFraudSignals(stats = {}) {
  const events = Math.max(0, Number(stats.total_events) || 0);
  const distinctIps = Math.max(0, Number(stats.distinct_ips) || 0);
  const distinctDevices = Math.max(0, Number(stats.distinct_devices) || 0);
  const distinctActors = Math.max(0, Number(stats.distinct_actors) || 0);
  const views = Math.max(0, Number(stats.views_7d) || 0);
  const saves = Math.max(0, Number(stats.saves_7d) || 0);
  const contacts = Math.max(0, Number(stats.contacts_7d) || 0);

  if (!events) return { fraudScore: 0, concentration: 0, actorConcentration: 0, conversionAnomaly: 0 };

  const ipConcentration = 1 - ratio(distinctIps, events);
  const deviceConcentration = 1 - ratio(distinctDevices, events);
  const actorConcentration = 1 - ratio(distinctActors, events);

  // Extremely high conversion from views into saves/contacts is a useful
  // anomaly signal, but it is capped and carries less weight than identity
  // concentration to avoid punishing genuinely excellent players.
  const saveRate = ratio(saves, Math.max(views, 1));
  const contactRate = ratio(contacts, Math.max(saves, 1));
  const conversionAnomaly = clamp(Math.max(0, saveRate - 0.8) * 0.5 + Math.max(0, contactRate - 0.5) * 0.5);

  const concentration = clamp(
    ipConcentration * 0.30 + deviceConcentration * 0.35 + actorConcentration * 0.20 + conversionAnomaly * 0.15
  );

  return {
    fraudScore: Math.round(concentration * 100) / 100,
    concentration: Math.round((ipConcentration * 0.5 + deviceConcentration * 0.5) * 100) / 100,
    actorConcentration: Math.round(actorConcentration * 100) / 100,
    conversionAnomaly: Math.round(conversionAnomaly * 100) / 100,
  };
}

function applyFraudPenalty(score, fraudScore, options = {}) {
  const hardThreshold = options.hardThreshold ?? 0.9;
  const maxPenalty = options.maxPenalty ?? 0.55;
  const risk = clamp(fraudScore);
  if (risk >= hardThreshold) return 0;
  return score * (1 - risk * maxPenalty);
}

module.exports = { computeFraudSignals, applyFraudPenalty, clamp };
