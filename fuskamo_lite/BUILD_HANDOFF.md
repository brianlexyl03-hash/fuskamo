# FUSKAMO Build Handoff

## Locked product configuration
- App name: FUSKAMO
- Android application ID: `com.fuskamo.fuskamo`
- Backend: existing custom backend
- Core platform: Supabase (Auth/Postgres/Storage/Realtime where configured)
- Kenya phone country code: `+254` (MCC `639`, ISO `ke`)

## Local runtime configuration
`.env` is included as a boot-safe placeholder. Replace its empty values with real project configuration before enabling live backend features.

Required values:
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `BACKEND_BASE_URL`
- `BACKEND_API_KEY` (when privileged backend operations are enabled)

Do not commit real secrets.

## Current verification status
- Backend automated suite: 39 passed, 1 skipped integration test because dependencies were not installed in the source-only environment.
- Dart relative-import structural check: passed.
- JavaScript syntax checks: passed.
- Database migration chain 001–027: contiguous.
- Android application ID and namespace: `com.fuskamo.fuskamo`.

## Remaining machine/cloud steps
This environment does not contain the Flutter/Dart SDK, so a literal Flutter compile/AAB build cannot be truthfully claimed here. On a machine with Flutter installed:

```bash
flutter pub get
flutter analyze
flutter test
flutter build appbundle --release
```

For a Play Store release, configure a real release keystore and production Supabase/backend credentials first. Do not ship a debug-signed AAB.
