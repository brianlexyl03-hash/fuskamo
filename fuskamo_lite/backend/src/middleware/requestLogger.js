const morgan = require('morgan');
const fs = require('fs');
const path = require('path');
const rfs = require('rotating-file-stream');
const env = require('../config/env');

const format = ':method :url :status :response-time ms';

/**
 * In production, rotate access logs daily on local disk as a fallback —
 * most hosts (Render, Railway, Fly.io) already capture stdout and rotate
 * it for you, so this only matters if you're running on bare infra without
 * that. In development, logs just go to stdout for readability.
 */
if (env.nodeEnv === 'production') {
  const logDir = path.join(__dirname, '../../logs-runtime');
  if (!fs.existsSync(logDir)) fs.mkdirSync(logDir, { recursive: true });
  const stream = rfs.createStream('access.log', { interval: '1d', maxFiles: 14, path: logDir });
  module.exports = morgan(format, { stream });
} else {
  module.exports = morgan(format);
}
