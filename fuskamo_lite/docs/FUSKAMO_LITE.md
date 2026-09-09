# FUSKAMO Lite

FUSKAMO Lite is a lightweight Flutter entry point sharing the main application's Supabase account and database. It is designed for low-data/low-storage devices.

## Run

```bash
flutter pub get
flutter run -t lib/lite_main.dart
```

## Included

- Supabase email authentication
- Public social feed with text posts
- Player discovery/search
- Public groups list
- Lightweight messages surface
- Profile + logout
- Shared backend/database; no second account system

## Deliberately omitted

- Video hosting and large video downloads
- Reels playback
- Story media
- Heavy animations
- Admin tools
- Large media uploads

Video remains a Coming Soon feature until cloud storage/CDN resources are configured.

## Configuration

Uses the root `.env` with `SUPABASE_URL` and `SUPABASE_ANON_KEY`. The Lite client does not contain server-only secrets.
