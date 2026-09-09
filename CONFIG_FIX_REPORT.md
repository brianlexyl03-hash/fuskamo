# FUSKAMO configuration fixes

- Added safe blank root `.env` so flutter_dotenv has a real asset to load; secrets remain empty.
- Added `.env` to Flutter assets and updated the quality test accordingly.
- Added safe blank `backend/.env` template for local setup.
- Reclassified M-Pesa, AI, Redis, Firebase, SMS and SMTP as optional feature configuration; core Supabase/backend values are clearly separated.
- Removed the misleading hard-coded Android release password from `key.properties.example`.
- Removed the stale claim that a release keystore was shipped with the repository.
- Added `SETUP_ENV.md` with copyable configuration blocks and security boundaries.
- Fixed `npm run test:stress` and `npm run test:stress:heavy` to point to the actual root `tools/stress_test.js`.
- Updated the project quality test to match the corrected dotenv asset behavior.

## Verification

- `npm test`: 39 passed, 0 failed, 1 skipped.
- `npm run test:logic`: 38 passed, 0 failed.
- `npm run test:stress`: PASS.
- `npm run test:stress:heavy`: PASS.
- Node syntax checks for edited backend configuration/server files: PASS.
- `pubspec.yaml` YAML parse: PASS.

The skipped test is environment-dependent and is not claimed as passed.
