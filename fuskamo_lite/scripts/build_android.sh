#!/usr/bin/env bash
set -e
flutter pub get
flutter build appbundle --release
echo "Output: build/app/outputs/bundle/release/app-release.aab"
