// Minimal structured logger. Swap for winston/pino later if log volume
// justifies it — kept dependency-free for the MVP (see monitoring/README.md).
const level = (msg) => `[${new Date().toISOString()}] ${msg}`;

module.exports = {
  info: (msg) => console.log(level(`INFO  ${msg}`)),
  warn: (msg) => console.warn(level(`WARN  ${msg}`)),
  error: (msg, err) => console.error(level(`ERROR ${msg}`), err || ''),
};
