const test = require('node:test');
const assert = require('node:assert/strict');
const { createHeuristicModel, validateModel } = require('../services/playerDiscoveryV2/modelInterface');
const { buildFeatures, rankLightCandidates } = require('../services/playerDiscoveryV2/lightRanker');
const { rankDeepCandidates } = require('../services/playerDiscoveryV2/deepRanker');
const { rerankForDiversity } = require('../services/playerDiscoveryV2/diversity');
const { deterministicBucket, applyExploration } = require('../services/playerDiscoveryV2/exploration');
const { applyBoostMixer } = require('../services/playerDiscoveryV2/boostMixer');
const { computeFraudSignals } = require('../services/playerDiscoveryV2/fraudSignals');
const { runPlayerDiscoveryV2 } = require('../services/playerDiscoveryV2/orchestrator');

function player(id, overrides = {}) {
  return { id, status: 'approved', name: id, position: 'Striker', age: 20, country: 'Kenya', club: `Club-${id}`, foot: 'right', height: 180, profile_completeness: 0.9, quality_score: 0.8, fraud_score: 0.02, trust_score: 80, achievement_count: 4, views_7d: 20, saves_7d: 8, contacts_7d: 2, shares_7d: 3, created_at: new Date().toISOString(), featured_until: null, ...overrides };
}
function scout(overrides = {}) { return { id: 's1', preferred_positions: ['Striker'], preferred_countries: ['Kenya'], age_min: 18, age_max: 25, preferred_foot: 'right', preferred_height_min: 175, ...overrides }; }

test('model factory is executable and returns bounded multi-objective output', () => {
  const model = createHeuristicModel();
  validateModel(model);
  const result = model.predict({ match: 1, quality: 0.8, engagement: 0.4, trust: 1, freshness: 0.5, potential: 0.6, conversion: 0.2, safety: 1 });
  assert.ok(result.utility >= 0 && result.utility <= 1);
  assert.equal(Object.keys(result.objectives).length, 8);
});

test('light ranker produces deterministic cheap-cut features', () => {
  const features = buildFeatures(scout(), player('p1'));
  assert.ok(features.match > 0.8);
  const ranked = rankLightCandidates(scout(), [player('p1'), player('p2', { quality_score: 0.2 })]);
  assert.equal(ranked[0].player.id, 'p1');
});

test('deep ranker uses injected model interface', () => {
  const model = { name: 'test', version: '1', predict: () => ({ utility: 0.77, objectives: { match: 1 } }) };
  const result = rankDeepCandidates([{ player: player('p1'), features: {} }], { model });
  assert.equal(result[0].deepScore, 0.77);
});

test('diversity prefers a different country when one is overrepresented', () => {
  const rows = [player('a'), player('b'), player('c'), player('d', { country: 'Nigeria' })].map((p, i) => ({ player: p, deepScore: 1 - i * 0.01 }));
  const result = rerankForDiversity(rows, { limit: 4, countryCap: 2, clubCap: 10 });
  assert.equal(result[0].player.id, 'a');
  assert.ok(result.map(r => r.player.country).indexOf('Nigeria') < 3);
});

test('exploration is deterministic for the same subject and day', () => {
  const rows = Array.from({ length: 20 }, (_, i) => ({ player: player(String(i)), deepScore: 1 - i / 100 }));
  const a = applyExploration(rows, { subjectId: 's1', dateSalt: '2026-08-15', limit: 10, rate: 0.2 }).map(r => r.player.id);
  const b = applyExploration(rows, { subjectId: 's1', dateSalt: '2026-08-15', limit: 10, rate: 0.2 }).map(r => r.player.id);
  assert.deepEqual(a, b);
  assert.notEqual(deterministicBucket('s1', '1', '2026-08-15'), deterministicBucket('s2', '1', '2026-08-15'));
});

test('boost mixer only boosts active featured players and remains bounded', () => {
  const future = new Date(Date.now() + 3600000).toISOString();
  const rows = [{ player: player('boost', { featured_until: future }), deepScore: 0.5 }, { player: player('plain'), deepScore: 0.5 }];
  const result = applyBoostMixer(rows, { maxBoost: 0.15 });
  assert.ok(result[0].finalScore > result[1].finalScore);
  assert.ok(result[0].boostScore <= 0.15);
});

test('fraud signals identify concentration without exceeding 1', () => {
  const clean = computeFraudSignals({ total_events: 100, distinct_ips: 90, distinct_devices: 85, distinct_actors: 80, views_7d: 80, saves_7d: 10, contacts_7d: 2 });
  const bad = computeFraudSignals({ total_events: 100, distinct_ips: 1, distinct_devices: 1, distinct_actors: 1, views_7d: 100, saves_7d: 100, contacts_7d: 100 });
  assert.ok(clean.fraudScore < bad.fraudScore);
  assert.ok(bad.fraudScore <= 1);
});

test('orchestrator returns a complete ordered feed', () => {
  const rows = runPlayerDiscoveryV2({ scout: scout(), subjectId: 's1', candidates: [player('p1'), player('p2', { country: 'Nigeria' }), player('p3', { quality_score: 0.2 }), player('bad', { fraud_score: 0.95 })], options: { limit: 3, dateSalt: '2026-08-15' } });
  assert.equal(rows.length, 3);
  assert.deepEqual(rows.map(r => r.position), [1, 2, 3]);
  assert.ok(rows.every(r => typeof r.score === 'number' && r.modelVersion));
  assert.ok(!rows.some(r => r.player.id === 'bad'));
});
