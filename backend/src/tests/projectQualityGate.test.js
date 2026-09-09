const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '../../..');
const migrations = path.join(root, 'database', 'migrations');
const lib = path.join(root, 'lib');

function readAll(dir, ext) {
  const out = [];
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, entry.name);
    if (entry.isDirectory()) out.push(...readAll(p, ext));
    else if (!ext || p.endsWith(ext)) out.push(p);
  }
  return out;
}

test('migration chain is contiguous through 031', () => {
  const nums = readAll(migrations, '.sql')
    .map(p => path.basename(p).match(/^(\d+)_/))
    .filter(Boolean)
    .map(m => Number(m[1]))
    .sort((a,b) => a-b);
  assert.equal(nums.at(-1), 31);
  for (let i = 1; i <= 31; i++) assert.ok(nums.includes(i), `missing migration ${i}`);
});

test('Flutter runtime configuration cannot fail merely because .env is absent', () => {
  const config = fs.readFileSync(path.join(lib, 'config', 'app_config.dart'), 'utf8');
  assert.match(config, /try\s*\{[\s\S]*dotenv\.load/);
  assert.match(config, /catch\s*\(_\)/);
  const pubspec = fs.readFileSync(path.join(root, 'pubspec.yaml'), 'utf8');
  assert.match(pubspec, /- \.env\s*$/m);
  assert.ok(fs.existsSync(path.join(root, '.env')), 'blank local .env template must exist for flutter_dotenv asset loading');
});

test('required platform surfaces have implementation files', () => {
  const required = [
    'screens/messages_screen.dart','screens/message_requests_screen.dart',
    'screens/reels_screen.dart','screens/social_feed_screen.dart',
    'screens/groups_screen.dart','screens/group_admin_screen.dart',
    'screens/verification_center_screen.dart','screens/achievements_screen.dart',
    'screens/scoreboard_screen.dart','screens/search_screen.dart',
    'screens/moderation_center_screen.dart','screens/creator_analytics_screen.dart',
    'services/unified_recommendation_service.dart','services/offline_sync_service.dart',
    'services/deep_link_service.dart','services/platform_operations_service.dart','services/completion_hardening_service.dart','repositories/completion_hardening_repository.dart'
  ];
  for (const rel of required) assert.ok(fs.existsSync(path.join(lib, rel)), `missing ${rel}`);
});

test('player discovery v2 has executable pipeline stages', () => {
  const required = [
    'services/playerDiscoveryV2/fraudSignals.js',
    'services/playerDiscoveryV2/modelInterface.js',
    'services/playerDiscoveryV2/lightRanker.js',
    'services/playerDiscoveryV2/deepRanker.js',
    'services/playerDiscoveryV2/diversity.js',
    'services/playerDiscoveryV2/exploration.js',
    'services/playerDiscoveryV2/boostMixer.js',
    'services/playerDiscoveryV2/orchestrator.js',
    'repositories/playerDiscoveryV2Repository.js',
    'controllers/playerDiscoveryV2Controller.js',
    'routes/discoveryV2.routes.js',
  ];
  for (const rel of required) assert.ok(fs.existsSync(path.join(root, 'backend', 'src', rel)), `missing ${rel}`);
});

test('video remains explicitly gated instead of pretending storage exists', () => {
  const config = fs.readFileSync(path.join(lib, 'video', 'video_launch_config.dart'), 'utf8');
  assert.match(config, /COMING SOON/);
  const migration = fs.readFileSync(path.join(migrations, '023_video_infrastructure_coming_soon.sql'), 'utf8');
  assert.match(migration, /disabled|false/i);
});
