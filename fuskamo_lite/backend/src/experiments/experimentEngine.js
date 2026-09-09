const crypto = require('node:crypto');

function bucket(experimentKey, subjectId) {
  const digest = crypto.createHash('sha256').update(`${experimentKey}:${subjectId}`).digest();
  return digest.readUInt32BE(0) % 10000;
}

function assign(experiment, subjectId) {
  if (!experiment?.key || !subjectId || !experiment.enabled) return experiment?.control || 'control';
  const pct = Math.max(0, Math.min(100, Number(experiment.rolloutPercent ?? 100)));
  const variants = experiment.variants?.length ? experiment.variants : ['control', 'treatment'];
  const b = bucket(experiment.key, subjectId) / 100;
  if (b >= pct) return experiment.control || variants[0];
  return variants[Math.floor((bucket(experiment.key + ':variant', subjectId) / 10000) * variants.length) % variants.length];
}

module.exports = { bucket, assign };
