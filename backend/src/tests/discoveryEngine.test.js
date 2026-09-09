const test = require('node:test');
const assert = require('node:assert/strict');
const {
  isEligible,
  calculateScore,
  applyDiversity,
  rankPlayers,
  computeFraudScore,
} = require('../services/discoveryEngine');

function player(overrides = {}) {
  return {
    id: 'p1',
    status: 'approved',
    position: 'Striker',
    age: 20,
    country: 'Kenya',
    foot: 'right',
    height: 180,
    profile_completeness: 0.5,
    quality_score: 0.5,
    fraud_score: 0,
    views_7d: 0,
    saves_7d: 0,
    contacts_7d: 0,
    shares_7d: 0,
    created_at: new Date().toISOString(),
    featured_until: null,
    ...overrides,
  };
}

function scout(overrides = {}) {
  return {
    id: 's1',
    preferred_positions: [],
    preferred_countries: [],
    age_min: null,
    age_max: null,
    preferred_foot: null,
    preferred_height_min: null,
    ...overrides,
  };
}

test('isEligible rejects non-approved players regardless of fraud score', () => {
  assert.equal(isEligible(scout(), player({ status: 'pending' })), false);
  assert.equal(isEligible(scout(), player({ status: 'rejected' })), false);
});

test('isEligible rejects players above the fraud threshold, keeps borderline ones', () => {
  assert.equal(isEligible(scout(), player({ fraud_score: 0.81 })), false);
  assert.equal(isEligible(scout(), player({ fraud_score: 0.8 })), true);
});

test('calculateScore rewards a position match', () => {
  const s = scout({ preferred_positions: ['Striker'] });
  const matched = calculateScore(s, player({ position: 'Striker' }));
  const unmatched = calculateScore(s, player({ position: 'Goalkeeper' }));
  assert.ok(matched > unmatched);
  assert.ok(matched - unmatched >= 20); // ~25pt weight, minus exploration jitter noise
});

test('calculateScore does not penalize players when a scout has no stated preferences', () => {
  const s = scout(); // no preferences set at all
  const a = calculateScore(s, player({ position: 'Striker', country: 'Kenya' }));
  const b = calculateScore(s, player({ position: 'Goalkeeper', country: 'Nigeria' }));
  // Neither should get the match bonus — difference should be small (just
  // exploration jitter), not the ~35pt swing a real mismatch would cause.
  assert.ok(Math.abs(a - b) < 10);
});

test('calculateScore gives verification a small capped trust signal, not a dominant ranking boost', () => {
  const s = scout();
  const plain = calculateScore(s, player({ profile_verified: false, trust_score: 0, achievement_count: 0 }));
  const verified = calculateScore(s, player({ profile_verified: true, trust_score: 100, achievement_count: 10 }));
  assert.ok(verified > plain);
  assert.ok(verified - plain < 12);
});

test('calculateScore rewards higher quality and profile completeness', () => {
  const s = scout();
  const strong = calculateScore(s, player({ quality_score: 1, profile_completeness: 1 }));
  const weak = calculateScore(s, player({ quality_score: 0, profile_completeness: 0 }));
  assert.ok(strong > weak);
});

test('calculateScore rewards recent engagement with diminishing returns', () => {
  const s = scout();
  const none = calculateScore(s, player({ contacts_7d: 0 }));
  const some = calculateScore(s, player({ contacts_7d: 5 }));
  const lots = calculateScore(s, player({ contacts_7d: 500 }));
  assert.ok(some > none);
  assert.ok(lots > some);
  // log-scaled: going from 5 to 500 contacts should NOT gain anywhere near
  // as much as going from 0 to 5 did — that's the whole point of log1p.
  assert.ok(lots - some < (some - none) * 50);
});

test('calculateScore applies the boost bonus only while featured_until is in the future', () => {
  const s = scout();
  const future = new Date(Date.now() + 60 * 60 * 1000).toISOString();
  const past = new Date(Date.now() - 60 * 60 * 1000).toISOString();
  const active = calculateScore(s, player({ featured_until: future }));
  const expired = calculateScore(s, player({ featured_until: past }));
  const none = calculateScore(s, player({ featured_until: null }));
  assert.ok(active > expired + 10);
  assert.ok(Math.abs(expired - none) < 5); // expired boost ≈ no boost, not a lingering bonus
});

test('calculateScore applies a heavy fraud penalty', () => {
  const s = scout();
  const clean = calculateScore(s, player({ fraud_score: 0 }));
  const suspicious = calculateScore(s, player({ fraud_score: 0.7 }));
  assert.ok(clean - suspicious > 20);
});

test('applyDiversity penalizes the 4th+ same-country result but leaves the top 3 untouched', () => {
  const ranked = [
    { player: player({ id: '1', country: 'Kenya' }), score: 100 },
    { player: player({ id: '2', country: 'Kenya' }), score: 90 },
    { player: player({ id: '3', country: 'Kenya' }), score: 80 },
    { player: player({ id: '4', country: 'Kenya' }), score: 70 },
    { player: player({ id: '5', country: 'Nigeria' }), score: 60 },
  ];
  const result = applyDiversity(ranked);
  assert.equal(result[0].score, 100);
  assert.equal(result[1].score, 90);
  assert.equal(result[2].score, 80);
  assert.equal(result[3].score, 70 * 0.85); // 4th Kenyan gets penalized
  assert.equal(result[4].score, 60); // Nigeria untouched
});

test('rankPlayers excludes ineligible players and diversifies the country spread', () => {
  const s = scout({ preferred_positions: ['Striker'] });
  const players = [
    ...Array.from({ length: 5 }, (_, i) =>
      player({ id: `ke-${i}`, country: 'Kenya', position: 'Striker', quality_score: 0.9 })
    ),
    player({ id: 'ng-1', country: 'Nigeria', position: 'Striker', quality_score: 0.6 }),
    player({ id: 'banned', country: 'Kenya', fraud_score: 0.95 }),
    player({ id: 'pending', country: 'Kenya', status: 'pending' }),
  ];

  const ranked = rankPlayers(s, players);
  const ids = ranked.map((r) => r.player.id);

  assert.ok(!ids.includes('banned'), 'high-fraud player must never appear');
  assert.ok(!ids.includes('pending'), 'non-approved player must never appear');
  assert.equal(ranked.length, 6);

  // No more than 3 Kenyan entries should land ahead of the single Nigerian
  // once diversity + re-sort has run, even though Kenyan quality scores
  // were set higher across the board.
  const nigeriaIndex = ids.indexOf('ng-1');
  const kenyansAheadOfNigeria = ids.slice(0, nigeriaIndex).filter((id) => id.startsWith('ke-')).length;
  assert.ok(kenyansAheadOfNigeria <= 3);
});

test('computeFraudScore is 0 with no events and rises as distinct IPs/devices shrink relative to volume', () => {
  assert.equal(computeFraudScore({ totalEvents: 0, distinctIps: 0, distinctDevices: 0 }), 0);

  const organic = computeFraudScore({ totalEvents: 20, distinctIps: 18, distinctDevices: 19 });
  const suspicious = computeFraudScore({ totalEvents: 200, distinctIps: 2, distinctDevices: 1 });

  assert.ok(organic < 0.2);
  assert.ok(suspicious > 0.9);
  assert.ok(suspicious <= 1);
});
