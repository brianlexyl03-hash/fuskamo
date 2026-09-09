# Testing

`test/widget_test.dart` has one smoke test to start from. Run with:
```bash
flutter test
```

## Manual checklist before each release
- [ ] App builds and installs on a physical Android device
- [ ] Feed shows empty state with no approved players, and real cards once some exist
- [ ] Filter chips correctly filter the feed
- [ ] Upload form validates required fields
- [ ] Upload form successfully inserts a row into `players` (check Supabase table)
- [ ] Video attach uploads to Storage and the row's `video_url` is set
- [ ] Scouts screen shows empty state with no verified scouts
- [ ] Bottom nav switches all 5 tabs correctly, state preserved via IndexedStack
