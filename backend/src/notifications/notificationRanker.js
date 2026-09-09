const { rankCandidates } = require('../ranking/rankingEngine');
function rankNotifications(items, { limit = 20 } = {}) {
  return rankCandidates((items || []).map((n, i) => ({ ...n, id: n.id || String(i), type: 'notification', quality: n.importance ?? .5, freshness: n.freshness ?? .5, affinity: n.affinity ?? .5, safety: 1, diversityKey: n.authorId || n.type, negativeFeedback: n.muted ? 1 : 0 })), { limit, authorCap: 2, minimumSafety: 1, seenPenalty: .25, negativePenalty: 1 });
}
module.exports = { rankNotifications };
