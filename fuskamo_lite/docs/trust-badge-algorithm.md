# FUSKAMO Trust, Achievement & Verification Algorithm V2

## Non-negotiable rule

**A tick is identity/affiliation verification. It is not a popularity prize, follower milestone, paid feature or ranking boost.**

- Gold tick = verified club
- Blue tick = verified scout
- Black tick = verified player or coach
- No tick = unverified account

Likes, achievements, profile appearance and endorsements can increase a **trust score** and earn recognition awards. None can independently create a tick.

## 1. Profile appearance score

The public profile is scored for completeness because a complete, consistent profile is more useful to other users:

- Display name: 10 raw points
- Username: 8
- Bio >= 30 characters: 8
- Avatar: 8
- Website: 6
- Instagram/X/TikTok presence: 5
- Role context: 5 for club/scout/coach, 2 for other roles

Raw maximum = 50. `profile_completion = raw / 50 * 100`.

**This score does not verify identity.**

## 2. Trust score used by discovery

The discovery trust signal is deterministic and bounded:

`trust = appearance*0.35 + recognition*0.20 + verified_endorsements*0.25 + safety*0.10 + role_consistency*0.10`

All components are normalized to 0..100.

### Recognition

Profile likes are logarithmic and capped at 250:

`recognition = ln(1 + min(likes,250)) / ln(251) * 100`

Therefore 2,500 likes does not produce ten times the trust of 250 likes.

### Verified endorsements

Only endorsements from currently verified accounts count. Five is the cap.

### Safety

`100 - fraud_score*100`, clamped to 0..100.

### Important anti-loop rule

Verification achievements are **not** counted as positive achievements inside trust calculation. Otherwise a tick could create trust, which could create more ranking, which could indirectly reinforce the same tick.

## 3. Achievements

Achievements are separate recognition:

- Complete Profile — 80%+ profile completeness
- Community Rising — 25 authentic profile likes
- Well Known — 250 authentic profile likes
- Trusted by Verified Members — 5 verified endorsements
- Club/Scout/Coach/Player Confirmed — only after actual verification approval

Achievements can improve discovery slightly, but **never grant a tick**.

## 4. Verification evidence score

A verification application receives an evidence-completeness score for the reviewer. It is not an automatic award score.

Signals include:

- claimed identity
- country
- official website
- official email
- official domain
- verified domain challenge
- registration number
- governing body
- professional license
- identity evidence
- organization evidence
- independent evidence URLs
- official social links

A strong package is a **strong review candidate**. The system still requires human review.

### Club authenticity

Clubs receive the strongest organization checks:

1. Legal/registration information where applicable.
2. Official website/domain.
3. Organization-domain email where available.
4. DNS TXT or other domain-control challenge.
5. Governing-body information where applicable.
6. Independent public evidence.
7. Consistency between the claimed club, website, country and submitted evidence.
8. Human reviewer confirms the evidence belongs to the claimed organization.

Domain control proves control of a domain; it does not, by itself, prove that the applicant is the legitimate organization. It is therefore only one signal.

## 5. Badge award pipeline

`application -> evidence scoring -> reviewer investigation -> decision -> audit event -> badge`

The award function has a hard invariant:

**Only an approved verification application can set `profiles.verified=true` and assign `badge_type`.**

Payment, boosts, likes, followers, achievements and profile completeness are outside the award function.

## 6. Expiration

Verification expires after one year. Expired badges are removed and require another review.

Revoked/rejected applications remove the tick immediately.

## 7. Non-affiliation protection

If an unverified profile references a club/person, show:

> Not affiliated with [name] unless this profile displays a FUSKAMO verification badge.

The applicant also accepts an anti-impersonation declaration. Fraudulent affiliation or forged evidence can lead to platform enforcement and may be referred for legal action where applicable.

## 8. Discovery ranking

The discovery engine uses trust only as a **small capped signal**. Verification does not dominate player quality, scout preference matching, engagement, freshness or safety.

Boosts may affect content discovery while active, but **boosts never affect verification or trust calculation**.

The ranking is now deterministic: the previous random jitter has been removed so identical inputs produce identical scores and are reproducible in testing.
