const test = require('node:test');
const assert = require('node:assert/strict');
const { rankCandidates, scoreCandidate } = require('../services/unifiedGraphEngine');

test('safety gate prevents risky candidates from ranking', () => {
  const result = scoreCandidate({ author_id: 'a', object_type: 'post', quality: 100, trust: 100, safety: 20, created_at: new Date() }, {});
  assert.equal(result.score, -Infinity);
});

test('relationship is meaningful but not dominant over safety', () => {
  const result = scoreCandidate({ author_id: 'a', object_type: 'post', quality: 50, trust: 50, safety: 100, engagement: 20, created_at: new Date() }, { following: new Set(['a']) });
  assert.ok(result.score > 20);
});

test('ranker diversifies repeated authors', () => {
  const candidates = Array.from({ length: 5 }, (_, i) => ({ author_id: 'same', object_type: 'post', object_id: String(i), quality: 100-i, trust: 80, safety: 100, engagement: 50, created_at: new Date() }));
  const other = { author_id: 'other', object_type: 'reel', object_id: 'x', quality: 80, trust: 80, safety: 100, engagement: 20, created_at: new Date() };
  const ranked = rankCandidates([...candidates, other], {}, 6);
  assert.equal(ranked.length, 6);
  assert.ok(ranked[3].candidate.author_id === 'other' || ranked[4].candidate.author_id === 'other' || ranked[5].candidate.author_id === 'other');
});
