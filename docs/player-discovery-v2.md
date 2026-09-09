# FUSKAMO Player Discovery V2

Player Discovery V2 is an additive, football-domain ranking pipeline. It is intentionally separate from the existing unified social recommendation system.

## Pipeline

1. Candidate generation — approved players plus recent engagement/fraud aggregates.
2. Fraud signals — IP/device/actor concentration and conversion anomaly.
3. Light ranker — cheap bounded feature cut.
4. Deep ranker — multi-objective model interface. The shipped v2.0.0 model is deterministic and executable; a learned model can be registered through the model registry contract.
5. Repetition control — recent-player penalty.
6. Diversity — country and club caps.
7. Boost mixer — active featured boosts are capped and combined with trust.
8. Exploration — deterministic slot reservation based on subject/player/day hash; no uncontrolled Math.random().
9. Impression logging — ranking_impressions stores model/version/position for evaluation.

## Compatibility

- `/api/discovery/*` remains V1.
- `/api/discovery/v2/*` is V2.
- V1 is retained as a fallback during rollout.
- Social recommendation endpoints are untouched.

## Model contract

A model implements:

```js
predict(features) => { utility: 0..1, objectives: {...} }
```

This lets a trained model replace the deterministic heuristic without changing the pipeline stages.
