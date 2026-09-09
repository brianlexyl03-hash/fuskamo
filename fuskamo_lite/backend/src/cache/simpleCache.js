const NodeCache = require('node-cache');
// Default 5-minute TTL — use for cheap wins like caching the external
// countries list (services/externalApiService.js) so you're not hitting a
// third-party API on every single form load.
module.exports = new NodeCache({ stdTTL: 300 });
