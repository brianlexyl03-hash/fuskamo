'use strict';

/**
 * FUSKAMO Unified Graph Ranker.
 * Identity -> social graph -> content -> recommendation -> scoreboard -> safety.
 * This is deliberately deterministic and explainable. It is a candidate ranker,
 * not a claim of trained ML. A future learned model can replace scoreCandidate()
 * without changing the candidate/event contracts.
 */

const MODEL_VERSION = 'unified-v2';
const EXPLORATION_BONUS = 6;
const NEGATIVE_WEIGHT = 16;
const REPORT_WEIGHT = 28;
const MAX_AUTHOR_RUN = 3;
const MAX_TYPE_RUN = 4;
const FRESHNESS_DAYS = 14;

const clamp = (n, min = 0, max = 100) => Math.min(max, Math.max(min, Number(n) || 0));
const logSignal = (n, cap = 100) => Math.min(cap, Math.log1p(Math.max(0, Number(n) || 0)) / Math.log1p(1000) * cap);

function daysOld(value, now = Date.now()) {
  const t = value ? new Date(value).getTime() : now;
  return Math.max(0, (now - t) / 86400000);
}

function freshness(createdAt, now = Date.now()) {
  return Math.max(0, 1 - daysOld(createdAt, now) / FRESHNESS_DAYS);
}

function scoreCandidate(candidate, context = {}) {
  const relationship = context.following?.has(candidate.author_id) ? 100 : 0;
  const roleAffinity = context.preferredRoles?.includes(candidate.role) ? 100 : 0;
  const quality = clamp(candidate.quality);
  const trust = clamp(candidate.trust);
  const safety = clamp(candidate.safety);
  const engagement = logSignal(candidate.engagement, 100);
  const momentum = clamp(candidate.momentum ?? candidate.engagement ?? 0);
  const creatorAffinity = clamp(candidate.creator_affinity ?? 0);
  const categoryAffinity = clamp(candidate.category_affinity ?? 0);
  const fresh = freshness(candidate.created_at, context.now);

  // Safety is a gate first and a penalty second. We do not recommend severely
  // risky accounts even if they are popular.
  if (safety < 25) return { score: -Infinity, reason: 'safety_gate' };

  let score = 0;
  score += relationship * 18;
  score += roleAffinity * 6;
  score += creatorAffinity * 0.10;
  score += categoryAffinity * 0.08;
  score += quality * 0.20;
  score += trust * 0.16;
  score += safety * 0.12;
  score += engagement * 0.10;
  score += momentum * 0.06;
  score += fresh * 16;

  // Exploration prevents a mature account from seeing only people it already follows.
  if (!relationship) score += EXPLORATION_BONUS;

  // Negative feedback is stronger than a positive click.
  score -= clamp(context.negativeByAuthor?.get(candidate.author_id) || 0) * NEGATIVE_WEIGHT;
  score -= clamp(context.reportPenaltyByAuthor?.get(candidate.author_id) || 0) * REPORT_WEIGHT;

  // Diversity and exploration are bounded so a niche creator cannot be buried forever.
  const recentAuthorCount = context.recentAuthorCounts?.get(candidate.author_id) || 0;
  const recentTypeCount = context.recentTypeCounts?.get(candidate.object_type) || 0;
  score -= Math.min(12, recentAuthorCount * 3);
  score -= Math.min(8, recentTypeCount * 1.5);

  return { score, reason: relationship ? 'relationship+quality' : 'quality+exploration' };
}

function diversify(ranked) {
  const authorCounts = new Map();
  const typeCounts = new Map();
  const output = [];

  for (const entry of ranked) {
    const author = entry.candidate.author_id;
    const type = entry.candidate.object_type;
    const a = authorCounts.get(author) || 0;
    const t = typeCounts.get(type) || 0;
    let penalty = 1;
    if (a >= MAX_AUTHOR_RUN) penalty *= 0.72;
    if (t >= MAX_TYPE_RUN) penalty *= 0.84;
    output.push({ ...entry, score: entry.score * penalty });
    authorCounts.set(author, a + 1);
    typeCounts.set(type, t + 1);
  }

  return output.sort((a, b) => b.score - a.score);
}

function rankCandidates(candidates, context = {}, limit = 30) {
  const ranked = candidates
    .map((candidate) => {
      const result = scoreCandidate(candidate, context);
      return { candidate, score: result.score, reason: result.reason };
    })
    .filter((x) => Number.isFinite(x.score))
    .sort((a, b) => b.score - a.score);

  return diversify(ranked).slice(0, Math.max(1, Math.min(limit, 100)));
}

function explain(entry) {
  return {
    model_version: MODEL_VERSION,
    score: Math.round(entry.score * 100) / 100,
    reason: entry.reason,
  };
}

module.exports = {
  MODEL_VERSION,
  scoreCandidate,
  rankCandidates,
  diversify,
  explain,
  daysOld,
  freshness,
};
