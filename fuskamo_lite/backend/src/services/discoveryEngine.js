'use strict';

/**
 * Scout–Player Discovery & Ranking Engine.
 *
 * Answers "which players should this scout see first?" by combining
 * profile match, quality, 7-day engagement, freshness, boosts, and a fraud
 * penalty, then re-balancing the result so one country can't dominate the
 * top of the feed.
 *
 * Pure functions only — no I/O, no Supabase/pg imports. discoveryRepository.js
 * is responsible for fetching the scout row and the candidate players (with
 * their 7-day engagement aggregates already computed) and handing them here.
 * That split is what makes this module trivially unit-testable — see
 * tests/discoveryEngine.test.js — and keeps the actual ranking rules in one
 * place instead of scattered across SQL.
 *
 * @typedef {Object} PlayerCandidate
 * @property {string} id
 * @property {string} status               'pending' | 'approved' | 'rejected'
 * @property {string} position
 * @property {number} age
 * @property {string} country
 * @property {string|null} [foot]           'left' | 'right' | 'both'
 * @property {number|null} [height]
 * @property {number} [profile_completeness] 0..1
 * @property {number} [quality_score]        0..1
 * @property {number} [fraud_score]          0..1
 * @property {number} [views_7d]
 * @property {number} [saves_7d]
 * @property {number} [contacts_7d]
 * @property {number} [shares_7d]
 * @property {string|Date|null} [created_at]
 * @property {string|Date|null} [featured_until]
 * @property {boolean} [profile_verified]
 * @property {string} [badge_type]
 * @property {number} [trust_score] 0..100
 * @property {number} [achievement_count]
 *
 * @typedef {Object} ScoutPreferences
 * @property {string} id
 * @property {string[]|null} [preferred_positions]
 * @property {string[]|null} [preferred_countries]
 * @property {number|null} [age_min]
 * @property {number|null} [age_max]
 * @property {string|null} [preferred_foot]
 * @property {number|null} [preferred_height_min]
 *
 * @typedef {Object} RankedPlayer
 * @property {PlayerCandidate} player
 * @property {number} score
 */

const FRAUD_ELIGIBILITY_THRESHOLD = 0.8; // above this, a player never enters the feed at all
const MAX_PER_COUNTRY_BEFORE_PENALTY = 3; // 4th+ same-country result in the ranked list gets penalized
const DIVERSITY_PENALTY_MULTIPLIER = 0.85;
const FRESHNESS_WINDOW_DAYS = 20; // freshness bonus decays to 0 by this many days old
const BOOST_BONUS = 18; // matches the M-Pesa "boost" flow's featured_until field
const TRUST_SIGNAL_MAX = 3;
const ACHIEVEMENT_SIGNAL_MAX = 2;

/**
 * @param {ScoutPreferences} scout
 * @param {PlayerCandidate} player
 * @returns {boolean}
 */
function isEligible(scout, player) {
  if (player.status !== 'approved') return false;
  if ((player.fraud_score ?? 0) > FRAUD_ELIGIBILITY_THRESHOLD) return false;
  return true;
}

/**
 * @param {ScoutPreferences} scout
 * @param {PlayerCandidate} player
 * @returns {number}
 */
function calculateScore(scout, player) {
  let score = 0;

  const preferredPositions = scout.preferred_positions || [];
  const preferredCountries = scout.preferred_countries || [];

  // Unset preference = neutral (no bonus, no penalty). Only an actual
  // match earns points, so a scout who hasn't configured preferences yet
  // still gets a sane feed driven by quality/engagement/freshness alone.
  if (preferredPositions.includes(player.position)) score += 25;
  if (preferredCountries.includes(player.country)) score += 10;

  const ageMin = scout.age_min;
  const ageMax = scout.age_max;
  if ((ageMin == null || player.age >= ageMin) && (ageMax == null || player.age <= ageMax)) {
    score += 15;
  }

  if (scout.preferred_foot && player.foot && scout.preferred_foot === player.foot) {
    score += 8;
  }

  if (scout.preferred_height_min && player.height && player.height >= scout.preferred_height_min) {
    score += 5;
  }

  score += (player.profile_completeness ?? 0) * 10;
  score += (player.quality_score ?? 0) * 15;

  // Verification is a small trust signal, never a substitute for football quality.
  // A tick cannot be purchased and contributes only a capped amount to discovery.
  // Trust is a capped discovery signal. The tick itself is intentionally
  // NOT awarded ranking power beyond the same small trust cap.
  score += Math.min(TRUST_SIGNAL_MAX, Math.max(0, (player.trust_score ?? 0) / 100 * TRUST_SIGNAL_MAX));
  score += Math.min(ACHIEVEMENT_SIGNAL_MAX, (player.achievement_count ?? 0) * 0.5);

  // log1p-style dampening so one viral player doesn't blow every other
  // signal out of the water — 10 saves matters a lot more than 1, but 1000
  // saves shouldn't matter 1000x more than 1.
  score += Math.log((player.views_7d ?? 0) + 1) * 3;
  score += Math.log((player.saves_7d ?? 0) + 1) * 8;
  score += Math.log((player.contacts_7d ?? 0) + 1) * 15; // a scout contacting a player is the strongest signal there is
  score += Math.log((player.shares_7d ?? 0) + 1) * 5;

  const uploadedAt = player.created_at ? new Date(player.created_at) : new Date();
  const daysSinceUpload = (Date.now() - uploadedAt.getTime()) / 86400000;
  score += Math.max(0, FRESHNESS_WINDOW_DAYS - daysSinceUpload);

  if (player.featured_until && new Date(player.featured_until) > new Date()) {
    score += BOOST_BONUS;
  }

  score -= (player.fraud_score ?? 0) * 40;

  return score;
}

/**
 * Penalizes the 4th-and-later result from the same country so the feed
 * doesn't read as five submissions from one country in a row.
 *
 * Takes an already score-sorted list (unlike the naive version of this
 * algorithm, which applies the penalty in arbitrary DB-fetch order — that
 * makes the "4th from this country" count depend on which row Postgres
 * happened to return first, not on actual rank. Sorting first means the
 * penalty always lands on the true 4th-highest-scored entry from that
 * country, which is the behavior "no more than 3 in a row" is supposed to
 * describe).
 *
 * @param {RankedPlayer[]} sortedRanked
 * @returns {RankedPlayer[]}
 */
function applyDiversity(sortedRanked) {
  const countryCount = {};
  return sortedRanked.map((entry) => {
    const country = entry.player.country;
    const seen = countryCount[country] || 0;
    countryCount[country] = seen + 1;
    if (seen >= MAX_PER_COUNTRY_BEFORE_PENALTY) {
      return { player: entry.player, score: entry.score * DIVERSITY_PENALTY_MULTIPLIER };
    }
    return entry;
  });
}

/**
 * @param {ScoutPreferences} scout
 * @param {PlayerCandidate[]} players
 * @returns {RankedPlayer[]}
 */
function rankPlayers(scout, players) {
  const scored = players
    .filter((p) => isEligible(scout, p))
    .map((p) => ({ player: p, score: calculateScore(scout, p) }))
    .sort((a, b) => b.score - a.score);

  const diversified = applyDiversity(scored);

  return diversified.sort((a, b) => b.score - a.score);
}

/**
 * Fraud signal derived from 7-day event concentration: if a small number of
 * IPs or devices account for a disproportionate share of a player's events,
 * that's a stronger fraud signal than raw event volume. Pure function —
 * discoveryRepository.recomputeFraudScores() does the aggregation query and
 * writes the result back to players.fraud_score on a nightly cron
 * (see scheduledJobs.js).
 *
 * @param {{ totalEvents: number, distinctIps: number, distinctDevices: number }} stats
 * @returns {number} 0..1
 */
function computeFraudScore({ totalEvents, distinctIps, distinctDevices }) {
  if (!totalEvents) return 0;
  const duplicateIpRatio = 1 - Math.min(distinctIps, totalEvents) / totalEvents;
  const repeatedDeviceRatio = 1 - Math.min(distinctDevices, totalEvents) / totalEvents;
  const score = duplicateIpRatio * 0.5 + repeatedDeviceRatio * 0.5;
  return Math.min(1, Math.max(0, Math.round(score * 100) / 100));
}

module.exports = {
  rankPlayers,
  calculateScore,
  isEligible,
  applyDiversity,
  computeFraudScore,
  FRAUD_ELIGIBILITY_THRESHOLD,
  MAX_PER_COUNTRY_BEFORE_PENALTY,
};
