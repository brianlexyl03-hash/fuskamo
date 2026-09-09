const fs = require('fs');
const path = require('path');
const test = require('node:test');
const assert = require('node:assert/strict');

test('ships storage gate and processing pipeline schema', () => {
  const migration = fs.readFileSync(path.join(__dirname, '../../../database/migrations/023_video_infrastructure_coming_soon.sql'), 'utf8');
  assert.ok(migration.includes('video_storage_policy'));
  assert.ok(migration.includes('video_assets'));
  assert.ok(migration.includes('video_upload_sessions'));
  assert.ok(migration.includes('video_processing_jobs'));
  assert.ok(migration.includes('enabled boolean not null default false'));
  assert.ok(migration.includes('package_hls'));
});

test('never enables cloud storage by default', () => {
  const migration = fs.readFileSync(path.join(__dirname, '../../../database/migrations/023_video_infrastructure_coming_soon.sql'), 'utf8');
  assert.match(migration, /insert into video_storage_policy\(id\) values\(true\)/);
  assert.ok(migration.includes("provider text not null default 'not_configured'"));
});
