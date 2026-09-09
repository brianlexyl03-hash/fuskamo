#!/usr/bin/env bash
set -euo pipefail
flutter pub get
flutter run -t lib/lite_main.dart
