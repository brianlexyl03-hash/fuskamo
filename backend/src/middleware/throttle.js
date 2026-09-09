const slowDown = require('express-slow-down');

// Adds increasing delay (not a hard block) once a client crosses the
// threshold — softer than rate limiting, good for endpoints where you'd
// rather degrade gracefully than reject outright (e.g. /external/countries).
module.exports = slowDown({
  windowMs: 60 * 1000,
  delayAfter: 20,
  delayMs: (hits) => hits * 100,
});
