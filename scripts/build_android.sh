#!/usr/bin/env bash
set -euo pipefail

if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter SDK is required to build the Android release AAB." >&2
  exit 1
fi

if [ ! -f .env ]; then
  echo "Missing .env. Copy .env.example and configure the production public values." >&2
  exit 1
fi

if [ ! -f android/key.properties ]; then
  echo "Missing android/key.properties. Configure your developer-owned release keystore first." >&2
  exit 1
fi

if [ ! -f android/app/src/main/AndroidManifest.xml ]; then
  echo "Android project is incomplete: missing AndroidManifest.xml" >&2
  exit 1
fi

flutter pub get
flutter analyze
flutter test
flutter build appbundle --release --obfuscate --split-debug-info=build/symbols

echo "Release AAB: build/app/outputs/bundle/release/app-release.aab"
echo "Symbols: build/symbols/"
