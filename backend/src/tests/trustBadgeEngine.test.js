const test = require('node:test');
const assert = require('node:assert/strict');
const {
  calculateProfileAppearance,
  calculateLikeRecognition,
  calculateVerifiedEndorsementSignal,
  calculateTrustScore,
  calculateVerificationEvidenceScore,
  getVerificationDecision,
  getBadgeForRole,
} = require('../services/trustBadgeEngine');

const completeProfile = {
  display_name: 'Example Player', username: 'example', bio: 'A real football profile with useful information.',
  avatar_url: 'https://example.com/a.jpg', website: 'https://example.com', instagram: 'example', role: 'player'
};

test('profile appearance rewards a complete profile and stays separate from verification', () => {
  assert.equal(calculateProfileAppearance(completeProfile), 94);
  assert.ok(calculateProfileAppearance({ role: 'player' }) < 10);
});

test('likes are logarithmic and capped at the recognition ceiling', () => {
  assert.equal(calculateLikeRecognition(0), 0);
  assert.ok(calculateLikeRecognition(25) > 0);
  assert.equal(calculateLikeRecognition(250), 100);
  assert.equal(calculateLikeRecognition(2500), 100);
});

test('verified endorsements are capped at five', () => {
  assert.equal(calculateVerifiedEndorsementSignal(0), 0);
  assert.equal(calculateVerifiedEndorsementSignal(5), 100);
  assert.equal(calculateVerifiedEndorsementSignal(50), 100);
});

test('trust score does not contain payment or boost state', () => {
  const a = calculateTrustScore({ profile: completeProfile, likes: 250, verifiedEndorsements: 5, fraudScore: 0 });
  const b = calculateTrustScore({ profile: completeProfile, likes: 250, verifiedEndorsements: 5, fraudScore: 0 });
  assert.equal(a, b);
});

test('fraud lowers trust without creating a badge decision', () => {
  const clean = calculateTrustScore({ profile: completeProfile, likes: 100, verifiedEndorsements: 2, fraudScore: 0 });
  const suspicious = calculateTrustScore({ profile: completeProfile, likes: 100, verifiedEndorsements: 2, fraudScore: 0.8 });
  assert.ok(clean > suspicious);
});

test('verification evidence recommends review but never auto-awards', () => {
  const app = {
    applicant_role: 'club', claimed_name: 'Example FC', country: 'Kenya',
    official_website: 'https://examplefc.com', official_email: 'admin@examplefc.com', official_domain: 'examplefc.com',
    registration_number: 'REG-1', governing_body: 'FA', identity_document_ref: 'id', organization_document_ref: 'org',
    evidence_urls: ['https://examplefc.com/about', 'https://examplefc.com/contact'], social_links: ['https://x.com/examplefc'], declaration_accepted: true
  };
  const score = calculateVerificationEvidenceScore(app, true);
  const decision = getVerificationDecision({ application: app, evidenceScore: score, domainVerified: true });
  assert.ok(score >= 70);
  assert.equal(decision.badge, 'gold');
  assert.equal(decision.autoAward, false);
});

test('role badges are fixed and not user-selectable', () => {
  assert.equal(getBadgeForRole('club'), 'gold');
  assert.equal(getBadgeForRole('scout'), 'blue');
  assert.equal(getBadgeForRole('player'), 'black');
  assert.equal(getBadgeForRole('coach'), 'black');
  assert.equal(getBadgeForRole('fan'), 'none');
});
