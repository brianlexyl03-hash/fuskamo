# FUSKAMO Identity, Username & Scoreboard Policy

## Username rules

Every public account has one canonical `@username`.

- 3–20 characters
- lowercase letters, numbers and `_`
- must start with a letter
- no consecutive underscores
- reserved route/system/role names cannot be claimed
- unique case-insensitively
- username changes are limited to once every 30 days
- every change is recorded in `username_history`

Display names can change freely; usernames are the stable identity handle.

## Scoreboard

FUSKAMO Score is a 0–100 reputation/ranking score. It is deliberately different from verification.

| Signal | Weight |
|---|---:|
| Role-relevant quality | 30% |
| Trust | 20% |
| Authentic profile likes | 15% |
| Followers | 10% |
| Achievement points | 10% |
| 7-day momentum | 10% |
| Profile completeness | 5% |

Popularity signals use logarithmic caps so one viral account cannot overwhelm every other signal.

Fraud risk applies a capped multiplier and can never be overcome by paying for boosts.

## Verification boundary

A gold/blue/black tick is **not** awarded from scoreboard rank, likes, followers, payment, boosts, or achievement points.

- Gold: verified club
- Blue: verified scout
- Black: verified player or coach

Verification requires the evidence workflow and human approval. Domain control is supporting evidence, not proof by itself.

## Scoreboard categories

- Global
- Players
- Scouts
- Clubs
- Coaches
- Rising
- Trusted

Ties use deterministic secondary signals instead of random jitter.

## Anti-gaming

- self-likes/follows are rejected
- unconfirmed email accounts cannot create reputation signals
- blocked accounts cannot exchange reputation signals
- duplicate likes/follows are impossible through primary keys
- verification state is excluded from the score formula
- paid promotion is excluded from the score formula
- player fraud risk can reduce the score
- verification expires and requires re-review
