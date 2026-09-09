const SEARCH_VERSION = 'v1';
function buildDocument(entity) {
  return { id: String(entity.id), type: entity.type || 'profile', text: [entity.username, entity.displayName, entity.name, entity.bio, ...(entity.tags || [])].filter(Boolean).join(' '), updatedAt: new Date().toISOString(), version: SEARCH_VERSION };
}
module.exports = { SEARCH_VERSION, buildDocument };
