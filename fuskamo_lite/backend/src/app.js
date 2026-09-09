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

app.get('/metrics', async (req, res) => {
  res.set('Content-Type', metricsRegister.contentType);
  res.end(await metricsRegister.metrics());
});

app.use((req, res) => res.status(404).json({ error: true, message: 'Not found' }));
app.use(errorHandler);

module.exports = app;
