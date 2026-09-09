# Contributing

1. Run `flutter create . --platforms=android,ios ...` once (see README) before your first build.
2. Keep Supabase calls confined to `lib/services/` — screens and widgets should never import `supabase_flutter` directly.
3. No hardcoded personal data (player names, scout names, etc.) anywhere in `lib/` — all such data must come from Supabase at runtime.
4. One feature/fix per branch. Update `CHANGELOG.md` for user-facing changes.
5. Run `flutter test` and `flutter analyze` before opening a PR.
