# FUSKAMO Release

This package contains the FUSKAMO platform source and its variants:

- `lib/` + `android/` — **Full Flutter app** (primary Android release target).
- `fuskamo_lite/` — **Lite Flutter app**.
- `web-app/` — **user-facing Web app**.
- `admin-web/` — **admin Web console**.
- `backend/` + `database/` — shared server/database infrastructure.

A Play Store AAB is not committed in source. It must be generated with the developer-owned release keystore using `scripts/build_android.sh`.

See `RELEASE_PREFLIGHT.md` for the exact remaining external release steps.
