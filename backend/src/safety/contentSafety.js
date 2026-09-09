function inspectContent({ text = '', metadata = {} } = {}) {
  const normalized = String(text).toLowerCase();
  const signals = {
    spam: /(free money|click here|dm me for cash|crypto giveaway)/i.test(normalized),
    impersonation: Boolean(metadata.claimedIdentity && metadata.claimedIdentity !== metadata.accountIdentity),
    suspiciousLink: /(?:https?:\/\/)?(?:bit\.ly|tinyurl\.com|t\.co)\//i.test(normalized),
  };
  const risk = Object.values(signals).filter(Boolean).length / 3;
  return { signals, risk, action: risk >= .66 ? 'review' : risk >= .34 ? 'limit' : 'allow' };
}
module.exports = { inspectContent };
