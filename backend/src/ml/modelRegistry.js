class ModelRegistry {
  constructor() { this.models = new Map(); }
  register({ name, version, handler, metadata = {} }) {
    if (!name || !version || typeof handler !== 'function') throw new TypeError('name, version and handler required');
    const key = `${name}:${version}`; this.models.set(key, { name, version, handler, metadata, registeredAt: new Date().toISOString() }); return key;
  }
  get(name, version) { return this.models.get(`${name}:${version}`) || null; }
  list() { return [...this.models.values()].map(({handler, ...m}) => m); }
}
module.exports = { ModelRegistry };
