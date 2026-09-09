# iOS platform folder — needs one command to generate

Unlike `android/` (already committed and configured in this repo — see
the root README), `ios/` genuinely hasn't been generated yet. Flutter's
iOS scaffolding (Xcode project, Podfile, Info.plist, Runner target) comes
from the Flutter SDK's own templates and needs to be generated on a
machine with the SDK (and for building/signing, a Mac with Xcode).

## Fix

```bash
cd fuskamo_flutter
flutter create . --platforms=ios --org com.fuskamo --project-name fuskamo
```

This generates a real, current `ios/` folder around the existing `lib/` —
it does not touch your Dart code. Building and signing for TestFlight/App
Store still requires Xcode on macOS, which is a hard platform requirement
from Apple, not something any tool can work around.
