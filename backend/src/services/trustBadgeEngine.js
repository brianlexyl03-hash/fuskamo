'use strict';

/**
 * FUSKAMO Trust + Badge Award Engine.
 *
 * Core rule: popularity can earn recognition, never identity verification.
 * Payment/boost state is intentionally absent from every badge calculation.
 * Human review remains the final authority for a verification tick.
 */

const BADGE_BY_ROLE = Object.freeze({
  club: 'gold',
  scout: 'blue',
  player: 'black',
  coach: 'black',
});

const VERIFICATION_REVIEW_THRESHOLD = 70;
const VERIFIED_ENDORSEMENT_CAP = 5;
const LIKE_RECOGNITION_CAP = 250;

function clamp(value, min = 0, max = 100) {
  return Math.min(max, Math.max(min, Number(value) || 0));
}

function hasText(value) {
  return typeof value === 'string' && value.trim().length > 0;
}

/**
 * Profile appearance/completeness is a trust signal, not proof of identity.
 * Maximum raw points = 50, normalized to 0..100.
 */
function calculateProfileAppearance(profile = {}) {
  let points = 0;
  if (hasText(profile.display_name)) points += 10;
  if (hasText(profile.username)) points += 8;
  if (hasText(profile.bio) && profile.bio.trim().length >= 30) points += 8;
  if (hasText(profile.avatar_url)) points += 8;
  if (hasText(profile.website)) points += 6;
  if (hasText(profile.instagram) || hasText(profile.x_handle) || hasText(profile.tiktok)) points += 5;
  points += ['club', 'scout', 'coach'].includes(profile.role) ? 5 : 2;
  return Math.round((points / 50) * 10000) / 100;
}

/** Logarithmic recognition: 250 likes is enough to reach the cap. */
function calculateLikeRecognition(likes = 0) {
  const n = Math.max(0, Number(likes) || 0);
  return clamp((Math.log1p(Math.min(n, LIKE_RECOGNITION_CAP)) / Math.log1p(LIKE_RECOGNITION_CAP)) * 100);
}

/** Verified endorsements are stronger than raw popularity but capped. */
function calculateVerifiedEndorsementSignal(count = 0) {
  const n = Math.min(VERIFIED_ENDORSEMENT_CAP, Math.max(0, Number(count) || 0));
  return (n / VERIFIED_ENDORSEMENT_CAP) * 100;
}

/**
 * Trust score used by discovery. This is NOT a verification score.
 * 35% profile appearance + 20% recognition + 25% verified endorsements
 * + 10% account safety + 10% role consistency.
 */
function calculateTrustScore({ profile = {}, likes = 0, verifiedEndorsements = 0, fraudScore = 0, roleConsistent = true } = {}) {
  const appearance = calculateProfileAppearance(profile);
  const recognition = calculateLikeRecognition(likes);
  const endorsements = calculateVerifiedEndorsementSignal(verifiedEndorsements);
  const safety = clamp(100 - clamp(fraudScore) * 100);
  const role = roleConsistent ? 100 : 0;
  return Math.round((appearance * 0.35 + recognition * 0.20 + endorsements * 0.25 + safety * 0.10 + role * 0.10) * 100) / 100;
}

/**
 * Scores evidence supplied for a verification application. This only tells a
 * reviewer how complete/independent the evidence package is. It never grants
 * a badge by itself.
 */
function calculateVerificationEvidenceScore(application = {}, domainVerified = false) {
  let score = 0;
  const role = application.applicant_role;

  if (hasText(application.claimed_name)) score += 5;
  if (hasText(application.country)) score += 5;
  if (hasText(application.official_website)) score += 10;
  if (hasText(application.official_email)) score += 10;
  if (hasText(application.official_domain)) score += 5;
  if (domainVerified) score += 20;
  if (hasText(application.registration_number)) score += 15;
  if (hasText(application.governing_body)) score += 10;
  if (hasText(application.professional_license)) score += 10;
  if (hasText(application.identity_document_ref)) score += 10;
  if (hasText(application.organization_document_ref)) score += 10;
  if (Array.isArray(application.evidence_urls)) score += Math.min(10, application.evidence_urls.filter(hasText).length * 5);
  if (Array.isArray(application.social_links)) score += Math.min(5, application.social_links.filter(hasText).length * 2.5);

  // Existing FUSKAMO review can support player identity, but cannot replace it.
  if (role === 'player' && application.player_submission_approved === true) score += 15;

  // Do not allow double-counting of the same evidence to exceed 100.
  return Math.round(clamp(score) * 100) / 100;
}

function getBadgeForRole(role) {
  return BADGE_BY_ROLE[role] || 'none';
}

function getVerificationDecision({ application = {}, evidenceScore = 0, domainVerified = false, identityConsistent = true, impersonationRisk = false } = {}) {
  const score = clamp(evidenceScore);
  const blockers = [];
  if (application.declaration_accepted !== true) blockers.push('declaration_not_accepted');
  if (!hasText(application.claimed_name)) blockers.push('missing_claimed_name');
  if (!identityConsistent) blockers.push('identity_inconsistent');
  if (impersonationRisk) blockers.push('impersonation_risk');

  return {
    score,
    badge: getBadgeForRole(application.applicant_role),
    recommendation: blockers.length ? 'manual_review_required' : score >= VERIFICATION_REVIEW_THRESHOLD ? 'strong_review_candidate' : 'needs_more_evidence',
    domainVerified: Boolean(domainVerified),
    blockers,
    autoAward: false,
  };
}

module.exports = {
  BADGE_BY_ROLE,
  VERIFICATION_REVIEW_THRESHOLD,
  calculateProfileAppearance,
  calculateLikeRecognition,
  calculateVerifiedEndorsementSignal,
  calculateTrustScore,
  calculateVerificationEvidenceScore,
  getBadgeForRole,
  getVerificationDecision,
};
