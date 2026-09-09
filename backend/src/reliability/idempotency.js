const crypto = require('node:crypto');
function keyFor(raw) { return crypto.createHash('sha256').update(String(raw)).digest('hex'); }
function createIdempotencyRecord(key, operation, actorId, ttlMs = 24*60*60*1000) { return { key:keyFor(key), operation, actorId:actorId||null, expiresAt:new Date(Date.now()+ttlMs).toISOString(), response:null, statusCode:null }; }
module.exports = { keyFor, createIdempotencyRecord };
