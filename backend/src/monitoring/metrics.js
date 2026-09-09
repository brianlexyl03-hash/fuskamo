const client = require('prom-client');

// Standard process metrics (CPU, memory, event loop lag) plus a couple of
// app-specific counters. Scrape this from Prometheus at GET /metrics
// (see monitoring/prometheus.yml at repo root).
const register = new client.Registry();
client.collectDefaultMetrics({ register });

const httpRequestDuration = new client.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route', 'status'],
  registers: [register],
});

const mpesaPaymentsTotal = new client.Counter({
  name: 'mpesa_payments_total',
  help: 'Total M-Pesa payment attempts',
  labelNames: ['result'],
  registers: [register],
});

module.exports = { register, httpRequestDuration, mpesaPaymentsTotal };
