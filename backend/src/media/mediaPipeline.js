const crypto = require('node:crypto');

function createUploadPlan({ ownerId, mimeType, bytes, kind = 'image' }) {
  if (!ownerId) throw new Error('ownerId required');
  if (!Number.isInteger(bytes) || bytes <= 0) throw new Error('bytes must be positive');
  const allowed = kind === 'image' ? ['image/jpeg','image/png','image/webp','image/avif'] : ['video/mp4','video/webm','video/quicktime'];
  if (!allowed.includes(mimeType)) throw new Error(`Unsupported ${kind} type`);
  const id = crypto.randomUUID();
  return { id, ownerId, kind, mimeType, bytes, objectKey: `${kind}/${ownerId}/${id}`, stages: ['validate','virus_scan','moderate','transform','publish'] };
}

function videoManifestPlan(upload) {
  if (upload?.kind !== 'video') throw new Error('Video upload required');
  return { objectKey: upload.objectKey, outputs: ['thumbnail','hls_360p','hls_480p','hls_720p'], status: 'coming_soon' };
}
module.exports = { createUploadPlan, videoManifestPlan };
