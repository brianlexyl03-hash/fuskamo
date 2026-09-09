const { EventEmitter } = require('node:events');

class EventStream extends EventEmitter {
  constructor() { super(); this.clients = new Map(); }
  subscribe(id, send) { this.clients.set(id, send); return () => this.clients.delete(id); }
  publish(event) { for (const [id, send] of this.clients) { try { send(event); } catch { this.clients.delete(id); } } }
}
module.exports = { EventStream };
