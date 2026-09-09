const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

// Dependency-free contract test: the health route is verifiable even in a
// clean source checkout before npm install has populated node_modules.
test('health endpoint contract is present', () => {
  const routes = fs.readFileSync(path.join(__dirname, '..', 'routes', 'index.js'), 'utf8');
  assert.match(routes, /router\.get\(['"]\/health['"][\s\S]*status\s*:\s*['"]ok['"]/);
});

test('health endpoint runtime smoke test (when backend dependencies are installed)', async (t) => {
  try {
    require.resolve('express');
  } catch (_) {
    t.skip('Express dependencies are not installed in this source-only environment');
    return;
  }

  const http = require('node:http');
  const app = require('../app');
  const server = app.listen(0);
  try {
    const { port } = server.address();
    const result = await new Promise((resolve, reject) => {
      http.get(`http://127.0.0.1:${port}/api/health`, (res) => {
        let data = '';
        res.on('data', chunk => { data += chunk; });
        res.on('end', () => resolve({ statusCode: res.statusCode, data }));
      }).on('error', reject);
    });
    assert.equal(result.statusCode, 200);
    assert.deepEqual(JSON.parse(result.data), { status: 'ok' });
  } finally {
    await new Promise(resolve => server.close(resolve));
  }
});
