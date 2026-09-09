'use strict';

const { clamp } = require('./fraudSignals');

/**
 * Runtime contract for player ranking models.
 * A model MUST expose predict(features) and return bounded objectives.
 */
function validateModel(model) {
  if (!model || typeof model.predict !== 'function') {
    throw new TypeError('Ranking model must expose predict(features)');
  }
  return model;
}

function createHeuristicModel({ name = 'player-discovery-utility', version = 'v2.0.0', weights = {} } = {}) {
  const w = {
    match: 0.24,
    quality: 0.18,
    engagement: 0.16,
    trust: 0.12,
    freshness: 0.10,
    potential: 0.10,
    conversion: 0.06,
    safety: 0.04,
    ...weights,
  };

  return validateModel({
    name,
    version,
    metadata: { type: 'deterministic-utility', objectives: Object.keys(w) },
    predict(features = {}) {
      const utility = Object.entries(w).reduce((sum, [key, weight]) => sum + clamp(features[key]) * weight, 0);
      const objectives = {
        match: clamp(features.match),
        quality: clamp(features.quality),
        engagement: clamp(features.engagement),
        trust: clamp(features.trust),
        freshness: clamp(features.freshness),
        potential: clamp(features.potential),
        conversion: clamp(features.conversion),
        safety: clamp(features.safety),
      };
      return { utility: clamp(utility), objectives };
    },
  });
}

function createModelFactory(registry) {
  return function getModel({ name = 'player-discovery-utility', version = 'v2.0.0', weights } = {}) {
    const registered = registry && typeof registry.get === 'function' ? registry.get(name, version) : null;
    if (registered) return validateModel(registered.handler);
    return createHeuristicModel({ name, version, weights });
  };
}

module.exports = { validateModel, createHeuristicModel, createModelFactory };
