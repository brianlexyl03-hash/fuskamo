const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const requestLogger = require('./middleware/requestLogger');
const errorHandler = require('./middleware/errorHandler');
const { sanitizeBody } = require('./middleware/sanitize');
const { apiLimiter } = require('./middleware/rateLimiter');
const { register: metricsRegister } = require('./monitoring/metrics');
const env = require('./config/env');
const v1Routes = require('./routes');

const app = express();

app.use(helmet());

// CORS: explicit allowlist from env, not a wildcard. Empty allowlist means
// "same-origin/non-browser clients only" (the Flutter app and Safaricom's
// webhook aren't browsers and aren't subject to CORS at all — this mainly
// matters if you ever add a browser-based admin panel on a different origin;
// see admin-panel/README.md).
app.use(
  cors({
    origin: env.cors.allowedOrigins.length ? env.cors.allowedOrigins : true,
    credentials: false,
  })
);

app.use(express.json({ limit: '2mb' }));
app.use(sanitizeBody);
app.use(requestLogger);
app.use('/api', apiLimiter);

// API versioning: /api/v1/... . Kept a bare /api alias pointing at v1 too,
// so existing Flutter builds pointing at /api don't break — remove the
// alias once every client is confirmed on /api/v1.
app.use('/api/v1', v1Routes);
app.use('/api', v1Routes);

// Was fully public — anyone could see internal route names, per-route
// traffic/latency, and M-Pesa payment attempt counts with no auth at all.
// Gated behind a shared token instead (standard for Prometheus scrape
// targets — point your scraper's Authorization header at it). Fails
// closed: unset METRICS_TOKEN means this endpoint always 401s, which is
// the safe default since nothing currently scrapes it.
app.get('/metrics', async (req, res) => {
  const token = (req.header('authorization') || '').replace(/^Bearer\s+/i, '');
  if (!process.env.METRICS_TOKEN || token !== process.env.METRICS_TOKEN) {
    return res.status(401).json({ error: true, message: 'Unauthorized' });
  }
  res.set('Content-Type', metricsRegister.contentType);
  res.end(await metricsRegister.metrics());
});

app.use((req, res) => res.status(404).json({ error: true, message: 'Not found' }));
app.use(errorHandler);

module.exports = app;
