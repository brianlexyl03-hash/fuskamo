const clamp = (n) => Math.max(0, Math.min(1, Number.isFinite(n) ? n : 0));

function riskScore(input = {}) {
  const velocity = clamp((Number(input.actionsPerMinute) || 0) / 120);
  const reports = clamp((Number(input.reportsLast24h) || 0) / 20);
  const duplicate = clamp(Number(input.duplicateContentRate) || 0);
  const failedAuth = clamp((Number(input.failedAuths) || 0) / 20);
  const newAccount = input.accountAgeDays != null && Number(input.accountAgeDays) < 3 ? .15 : 0;
  const deviceFanout = clamp((Number(input.accountsPerDevice) || 0) / 10);
  return clamp(velocity*.25 + reports*.25 + duplicate*.15 + failedAuth*.15 + newAccount + deviceFanout*.2);
}

function decision(score) {
  if (score >= .85) return 'block';
  if (score >= .65) return 'challenge';
  if (score >= .45) return 'throttle';
  return 'allow';
}

module.exports = { riskScore, decision };
