#!/usr/bin/env bash
# Requires macOS + Xcode.
set -e
flutter pub get
flutter build ios --release
echo "Now archive/upload via Xcode."
