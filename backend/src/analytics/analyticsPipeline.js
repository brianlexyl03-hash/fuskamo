const { randomUUID } = require('node:crypto');

class AnalyticsPipeline {
  constructor({ maxBuffer = 10000, flushSize = 250 } = {}) { this.maxBuffer = maxBuffer; this.flushSize = flushSize; this.buffer = []; }
  record(type, subjectId, properties = {}) {
    if (!type) return false;
    if (this.buffer.length >= this.maxBuffer) this.buffer.shift();
    this.buffer.push({ id: randomUUID(), type, subjectId: subjectId || null, properties, occurredAt: new Date().toISOString() });
    return this.buffer.length >= this.flushSize;
  }
  drain(limit = this.flushSize) { return this.buffer.splice(0, Math.min(limit, this.buffer.length)); }
  size() { return this.buffer.length; }
}
module.exports = { AnalyticsPipeline };
