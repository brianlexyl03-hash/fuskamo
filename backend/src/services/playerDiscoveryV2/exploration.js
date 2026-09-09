'use strict';

const crypto = require('node:crypto');

function deterministicBucket(subjectId, itemId, salt = new Date().toISOString().slice(0, 10)) {
  const digest = crypto.createHash('sha256').update(`${salt}:${subjectId}:${itemId}`).digest();
  return digest.readUInt32BE(0) / 0xffffffff;
}

/** Reserves deterministic exploration slots instead of adding random jitter. */
function applyExploration(rows, options = {}) {
  const limit = Math.max(1, Number(options.limit) || 30);
  const rate = Math.max(0, Math.min(0.5, Number(options.rate ?? 0.12)));
  const subjectId = String(options.subjectId || 'anonymous');
  const dateSalt = options.dateSalt || new Date().toISOString().slice(0, 10);
  const reserve = Math.min(Math.floor(limit * rate), rows.length);
  if (!reserve) return rows.slice(0, limit);

  const sorted = [...rows].sort((a, b) => deterministicBucket(subjectId, a.player.id, dateSalt) - deterministicBucket(subjectId, b.player.id, dateSalt));
  const exploratory = sorted.slice(0, Math.min(rows.length, reserve * 4)).sort((a, b) => a.deepScore - b.deepScore).slice(0, reserve);
  const exploreIds = new Set(exploratory.map((r) => String(r.player.id)));
  const ranked = rows.filter((r) => !exploreIds.has(String(r.player.id)));
  const output = [];
  let ei = 0;
  let ri = 0;
  for (let position = 0; position < limit && (ei < exploratory.length || ri < ranked.length); position += 1) {
    const shouldExplore = (position + 1) % Math.max(2, Math.floor(limit / Math.max(1, reserve))) === 0 && ei < exploratory.length;
    output.push(shouldExplore ? exploratory[ei++] : ranked[ri++]);
  }
  while (output.length < limit && ri < ranked.length) output.push(ranked[ri++]);
  return output.slice(0, limit);
}

module.exports = { deterministicBucket, applyExploration };
