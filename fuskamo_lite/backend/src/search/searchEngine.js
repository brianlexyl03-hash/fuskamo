function normalizeText(value) {
  return String(value || '').normalize('NFKD').replace(/[\u0300-\u036f]/g, '').toLowerCase().trim();
}

function scoreSearchItem(query, item = {}) {
  const q = normalizeText(query);
  if (!q) return 0;
  const fields = [
    [item.username, 1.0], [item.displayName, .85], [item.name, .8], [item.clubName, .7], [item.position, .5], [item.bio, .35], [item.tags?.join?.(' '), .4],
  ];
  let score = 0;
  for (const [raw, weight] of fields) {
    const value = normalizeText(raw);
    if (!value) continue;
    if (value === q) score = Math.max(score, 1 * weight);
    else if (value.startsWith(q)) score = Math.max(score, .85 * weight);
    else if (value.includes(q)) score = Math.max(score, .65 * weight);
  }
  if (item.verified) score += .08;
  if (item.active) score += .03;
  return Math.min(1, score);
}

function search(query, items, { limit = 50 } = {}) {
  return (items || []).map(item => ({ item, score: scoreSearchItem(query, item) }))
    .filter(x => x.score > 0)
    .sort((a, b) => b.score - a.score || String(a.item.id).localeCompare(String(b.item.id)))
    .slice(0, Math.min(limit, 200));
}

module.exports = { normalizeText, scoreSearchItem, search };
