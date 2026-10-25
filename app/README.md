# SkiMapper app

The Flutter app for iOS and Android. Run it with `tools/dev-app <ios|android>` from the repo root, which
starts the local endpoint and passes its URL in with `--dart-define`; a bare `flutter run` has no
endpoint configured.

- `lib/` — app code, grouped by concern (`endpoint/`, `resorts/`, `map/`, `theme/`, `text/`, `attribution/`)
- `test/` — unit and widget tests (`flutter test`)
- `patrol_test/` — Patrol E2E tests, one folder per endpoint state (run with `tools/e2e`)
- `assets/map/` — the bundled fixture PMTiles

Commands for every test layer: [../docs/PIPELINE.md](../docs/PIPELINE.md).
