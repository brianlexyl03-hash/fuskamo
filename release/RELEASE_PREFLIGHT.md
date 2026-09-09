# FUSKAMO Release Preflight

## Confirmed in this source package

- Full Flutter application source is present at the repository root.
- Lite Flutter application is present under `fuskamo_lite/`.
- User-facing web client is present under `web-app/`.
- Admin web console is present under `admin-web/`.
- Backend source and tests are present under `backend/`.
- Database migrations 001–031 are present and sequential.
- Android application ID is `com.fuskamo.fuskamo`.
- Android release build is configured to target API 36.
- Release signing now fails closed unless `android/key.properties` and the developer-owned keystore are supplied.
- No server secrets are embedded in the source package.
- Video remains gated rather than pretending cloud video infrastructure is live.

## Verification performed in this environment

- Backend Node syntax: PASS.
- Backend automated suite: PASS after correcting the stale migration-count assertion and restoring the required blank `.env` asset.
- Dart package-import consistency: PASS (no undeclared package imports found).
- ZIP integrity: PASS for the supplied source archive before extraction.

## Final external release steps still require the developer environment

1. Supply real production `.env` public configuration.
2. Supply the developer-owned Android release keystore and `android/key.properties`.
3. Install the Flutter SDK and Android SDK/platform API 36.
4. Run `scripts/build_android.sh` and verify the generated AAB.
5. Test the release build on physical Android devices.
6. Apply/verify Supabase migrations against the production project.
7. Configure production backend, domain/CORS, notifications, and any enabled payment infrastructure.
8. Complete Play Console listing, privacy/data-safety declarations, content rating, testing track, and final submission.

No AAB is claimed here until the actual Flutter release build succeeds with the real production configuration and signing key.
