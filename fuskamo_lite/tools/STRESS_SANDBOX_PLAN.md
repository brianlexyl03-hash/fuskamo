# FUSKAMO Local Stress Sandbox

This sandbox is deliberately dependency-light. It does not need Flutter, Supabase, cloud storage, a CDN, paid APIs, or a network connection.

## Stress scenarios integrated

| ID | Scenario | Load | Pass condition |
|---|---|---:|---|
| S01 | Recommendation flood | 1,000,000 synthetic candidates | returns bounded top-100, sorted, no unsafe leakage |
| S02 | Trust calculation flood | 1,000,000 profiles | all scores finite and bounded |
| S03 | Player discovery flood | 500,000 candidates | ineligible/fraudulent candidates never leak |
| S04 | Adversarial numeric inputs | -Infinity, Infinity, NaN, huge integers, negatives | no non-finite ranking output except explicit safety gate |
| S05 | Safety gate pressure | 1/997 candidates severe risk | severe-risk candidates excluded |
| S06 | Diversity pressure | repeated authors/types/countries | diversity penalties remain bounded |
| S07 | Negative-feedback pressure | concentrated negative/report signals | negative signals can suppress popularity |
| S08 | Recognition inflation | large like counts | logarithmic cap prevents runaway trust |
| S09 | Verification inflation | large endorsement counts | endorsement cap remains enforced |
| S10 | Payment/boost isolation | trust calculation receives no payment fields | payment/boost cannot influence badge trust |
| S11 | Migration continuity | migrations 001 through 027 | no numbering gaps |
| S12 | Source structural integrity | all backend JS + Flutter Dart | syntax/structure/import checks pass |

## Heavy run used for V14

- 1,000,000 recommendation candidates
- 1,000,000 trust profiles
- 500,000 player-discovery candidates
- 7 adversarial numeric boundary values
- Node.js v22.16.0
- 3 CPU environment

This is a local algorithmic stress test. It is **not** a substitute for distributed load testing against a real Supabase/backend deployment, real Flutter rendering, or production video/CDN infrastructure.
