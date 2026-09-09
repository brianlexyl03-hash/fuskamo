'use strict';

function keyOf(player, key = 'country') {
  return String(player?.[key] || 'unknown');
}

function rerankForDiversity(rows, options = {}) {
  const limit = Math.max(1, Number(options.limit) || 30);
  const countryCap = Math.max(1, Number(options.countryCap) || 3);
  const clubCap = Math.max(1, Number(options.clubCap) || 2);
  const output = [];
  const remaining = [...(rows || [])];
  const counts = { country: new Map(), club: new Map() };

  while (remaining.length && output.length < limit) {
    let selectedIndex = 0;
    let bestAdjusted = -Infinity;
    for (let i = 0; i < remaining.length; i += 1) {
      const row = remaining[i];
      const country = keyOf(row.player, 'country');
      const club = keyOf(row.player, 'club');
      const countryCount = counts.country.get(country) || 0;
      const clubCount = counts.club.get(club) || 0;
      if (countryCount >= countryCap && remaining.length > (limit - output.length)) continue;
      const penalty = (countryCount >= countryCap ? 0.55 : 1) * (clubCount >= clubCap ? 0.70 : 1);
      const adjusted = row.deepScore * penalty;
      if (adjusted > bestAdjusted) { bestAdjusted = adjusted; selectedIndex = i; }
    }
    const [selected] = remaining.splice(selectedIndex, 1);
    output.push({ ...selected, diversityScore: bestAdjusted });
    const country = keyOf(selected.player, 'country');
    const club = keyOf(selected.player, 'club');
    counts.country.set(country, (counts.country.get(country) || 0) + 1);
    counts.club.set(club, (counts.club.get(club) || 0) + 1);
  }
  return output;
}

function repetitionPenalty(player, recentIds = [], recentLimit = 30) {
  const recent = new Set((recentIds || []).slice(0, recentLimit).map(String));
  return recent.has(String(player.id)) ? 0.45 : 1;
}

module.exports = { rerankForDiversity, repetitionPenalty };
