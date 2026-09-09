# Release

Empty on purpose:
- `keystore/` — generate your own signing key once (`keytool -genkey ...`), back it up securely outside git — losing it means you can never update the app under the same Play Store listing. Already gitignored.
- `app-release.aab` — produced by `scripts/build_android.sh`
- `screenshots/`, store listing copy — created from the real running app once the MVP is stable

Nothing here is faked ahead of time since the keystore is a one-time, security-sensitive artifact only you should generate.
