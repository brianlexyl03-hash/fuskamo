'use strict';

const { createHeuristicModel } = require('./modelInterface');
const { clamp } = require('./fraudSignals');

function rankDeepCandidates(candidates, options = {}) {
  const model = options.model || createHeuristicModel(options.modelOptions);
  const rows = (candidates || []).map((candidate) => {
    const prediction = model.predict(candidate.features || {});
    const utility = clamp(prediction.utility);
    return { ...candidate, prediction, deepScore: utility };
  });
  rows.sort((a, b) => b.deepScore - a.deepScore || String(a.player.id).localeCompare(String(b.player.id)));
  return rows;
}

module.exports = { rankDeepCandidates };
