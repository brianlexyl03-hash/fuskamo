# Push notifications — one-time setup

`lib/notifications/push_notification_service.dart` is fully implemented and
wired into the app (main.dart, AuthProvider), but FCM needs credentials
that only exist once you create a Firebase project — nobody can hand you
working ones for an app they don't own. This is the same category of step
as filling in `SUPABASE_URL` in `.env`, just on the Firebase side instead.

## 1. Create the Firebase project
1. Go to https://console.firebase.google.com → Add project.
2. Name it (e.g. `fuskamo`). Google Analytics is optional, skip it.

## 2. Add the Android app
1. In the Firebase console: Add app → Android.
2. Package name: `com.fuskamo.fuskamo` (matches `applicationId` in
   `android/app/build.gradle.kts` — the `android/` project is already
   committed in this repo, no `flutter create .` step needed).
3. Download `google-services.json`, place it at `android/app/google-services.json`.
4. In `android/build.gradle.kts`, add the Google services classpath; in
   `android/app/build.gradle.kts`, apply the `com.google.gms.google-services`
   plugin. (Exact snippets are in FlutterFire's official docs — they
   change with Gradle/AGP versions, so following the current FlutterFire
   guide here is safer than a snippet that may already be stale:
   https://firebase.google.com/docs/flutter/setup)

## 3. Add the iOS app
1. Add app → iOS, bundle ID matching `ios/Runner.xcodeproj`.
2. Download `GoogleService-Info.plist`, add it to `ios/Runner/` via Xcode
   (drag into the Runner target, not just the file tree).
3. Enable Push Notifications + Background Modes → Remote notifications
   under Xcode → Signing & Capabilities.

## 4. Verify
Run the app on a real device (FCM tokens don't reliably show up on
simulators/emulators). `PushNotificationService.init()` logs a permission
prompt and, once granted, registers a token into the `device_tokens` table
(migration `006_device_tokens.sql`) — check that table in Supabase after
signing in to confirm a row appeared.

## 5. Sending a push
This app only *receives* pushes and stores tokens — actually sending one
(e.g. "new talent in your region") is a backend job: read the relevant
tokens out of `device_tokens` and call the FCM HTTP v1 API with the
service-role Firebase Admin SDK. That's a `/backend` addition, not a
Flutter one, and isn't included in this batch.
