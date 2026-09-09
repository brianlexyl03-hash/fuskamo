const clamp = (n, lo = 0, hi = 1) => Math.max(lo, Math.min(hi, Number.isFinite(n) ? n : 0));

function normalizeCandidate(candidate = {}) {
  return {
    id: String(candidate.id || ''),
    authorId: String(candidate.authorId || candidate.userId || ''),
    type: candidate.type || 'post',
    affinity: clamp(candidate.affinity),
    quality: clamp(candidate.quality),
    freshness: clamp(candidate.freshness),
    safety: clamp(candidate.safety, 0, 1),
    diversityKey: candidate.diversityKey || candidate.authorId || candidate.id,
    negativeFeedback: clamp(candidate.negativeFeedback),
    seen: Boolean(candidate.seen),
  };
}

function rankCandidates(candidates, options = {}) {
  const weights = { affinity: .32, quality: .24, freshness: .18, safety: .16, diversity: .10, ...(options.weights || {}) };
  const seenPenalty = options.seenPenalty ?? .35;
  const negativePenalty = options.negativePenalty ?? .55;
  const limit = Math.max(1, Math.min(options.limit || 50, 500));
  const rows = [];
  for (const raw of candidates || []) {
    const c = normalizeCandidate(raw);
    if (!c.id || c.safety < (options.minimumSafety ?? .45)) continue;
    const base = c.affinity * weights.affinity + c.quality * weights.quality + c.freshness * weights.freshness + c.safety * weights.safety;
    const diversity = c.diversityKey ? 1 : 0;
    const score = base + diversity * weights.diversity - (c.seen ? seenPenalty : 0) - c.negativeFeedback * negativePenalty;
    if (!Number.isFinite(score)) continue;
    rows.push({ ...c, score });
  }
  rows.sort((a, b) => b.score - a.score || a.id.localeCompare(b.id));
  const output = [];
  const authorCounts = new Map();
  for (const row of rows) {
    const count = authorCounts.get(row.authorId) || 0;
    const cap = options.authorCap || 3;
    if (count >= cap) continue;
    output.push(row);
    authorCounts.set(row.authorId, count + 1);
    if (output.length >= limit) break;
  }
  return output;
}

module.exports = { rankCandidates, normalizeCandidate };
