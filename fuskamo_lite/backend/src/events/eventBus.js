const { EventEmitter } = require('node:events');

class PlatformEventBus extends EventEmitter {
  constructor() {
    super({ captureRejections: true });
    this.setMaxListeners(100);
  }

  publish(type, payload = {}, meta = {}) {
    const event = {
      id: meta.id || `${Date.now()}-${Math.random().toString(36).slice(2, 10)}`,
      type,
      occurredAt: new Date().toISOString(),
      version: meta.version || 1,
      actorId: meta.actorId || null,
      requestId: meta.requestId || null,
      payload,
    };
    this.emit(type, event);
    this.emit('*', event);
    return event;
  }
}

module.exports = { PlatformEventBus };
