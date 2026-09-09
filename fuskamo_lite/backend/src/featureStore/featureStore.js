class InMemoryFeatureStore {
  constructor({ maxKeys = 100000 } = {}) {
    this.maxKeys = maxKeys;
    this.values = new Map();
  }

  set(entityId, features, ttlMs = 15 * 60 * 1000) {
    if (!entityId || !features || typeof features !== 'object') throw new TypeError('Invalid feature payload');
    if (this.values.size >= this.maxKeys && !this.values.has(entityId)) this.values.delete(this.values.keys().next().value);
    this.values.set(entityId, { features: { ...features }, expiresAt: Date.now() + ttlMs });
  }

  get(entityId) {
    const item = this.values.get(entityId);
    if (!item) return null;
    if (item.expiresAt < Date.now()) { this.values.delete(entityId); return null; }
    return { ...item.features };
  }

  delete(entityId) { this.values.delete(entityId); }
  size() { return this.values.size; }
}

module.exports = { InMemoryFeatureStore };
