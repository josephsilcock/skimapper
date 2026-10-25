# Decisions

Noteworthy implementation decisions: choices between real alternatives, with the rationale and the
roads not taken. Area docs (`definitions/`) say *what* the system does; this file says *why it's
built that way* — so decisions don't get re-litigated from scratch. Origins reference the (deleted,
git-recoverable) spec that recorded the decision. Add entries via `/finish-feature`; most features
add zero or one.

When a decision here is overturned, update the entry (or delete it) in the same commit — like the
area docs, this file describes the present.

## Settled during C4 grilling

- **G1 Flutter for the app.** One codebase, Dart AOT for on-device routing. Rejected: React Native with Expo (more mature MapLibre binding), KMP with Compose (youngest map binding, heaviest iOS tooling). Consequence: offline maps are the riskiest choice, so the skeleton proved them first (D4).
- **G2 A thin edge endpoint over stored artefacts.** Rejected: a server with a database (free tiers sleep or pause); purely static hosting (C1 and C2 could not be enforced).
- ~~**G3 Repo starts private.**~~ Superseded by C5: the repo is public, so Actions minutes are free and `main` is PR-only.
- **G4 The sweep boots the named simulator and AVD itself**, so a missing device fails the sweep visibly.

## D1 Architecture and hosting

The device does rendering, routing, storage and location. A Cloudflare Worker (TypeScript) is the only public door, in front of private R2. A GitHub Actions cron runs the daily refresh. There is no status cron (D3). Free-tier fit is **unverified until the first deploy** (Workers: 100k requests a day, 10 ms CPU per request; R2: 10 GB-month, 1M writes, 10M reads a month, free egress).

Rejected: Supabase (pauses when idle); Render (sleeps after 15 minutes, 5 GB bandwidth); Fly.io and Railway (trial only); Firebase (functions need a paid plan); Oracle Always Free VM (always on, but we would own patching, TLS and uptime, and Oracle cut the free allowance without notice in June 2026); Vercel Hobby for everything (Blob limits of 1 GB storage and 10 GB transfer do not fit 5-25 MB map parts, and Hobby is non-commercial only); public R2 or CDN delivery of parts (breaks C1); a service per data kind (thousands of requests per resort, F18 cannot size or remove a resort).

## D2 Resort data from OpenSkiMap's exports

The exports' licence, especially ski-area fields derived from Skimap.org, is **unverified; F5 or F20, whichever first takes in OpenSkiMap data, must confirm it before shipping**. Fallback: raw OSM (Geofabrik extract, osmium, grouped by `landuse=winter_sports`). ODbL obligations: the app credits "© OpenStreetMap contributors" and the derived database is offered as a periodic dump on request (C1 limits bulk serving, not availability). Rejected: Skimap.org alone (no open licence for geometry).

## D3 Live status fetched in the Worker per request

`GET /v1/status/{resort}`: serve a cached copy younger than about 60 s, else fetch the resort's source page, parse it with that resort's adapter (`HTMLRewriter`), map names to our ids using the status key map from R2, and return it enveloped and stamped. Caching is in-memory best effort (the Cache API needs a custom domain; KV allows only 1,000 writes a day). Adapters are ported from Liftie's BSD-3 parsers; Liftie covers lifts only, a gap accepted (runs show "unknown", which F6 hides). Fallback order: Workers Paid ($5 a month), then a status-only Vercel Hobby function forwarded from the Worker, then an Oracle VM; triggers are more than about 5 ms CPU per resort (F6 measures) or resort sites blocking Cloudflare. F6 may add a last-good copy in R2, written only on change.

Rejected: the app fetching resort sites directly (fixing an adapter would need an app release, breaking F20; bypasses C1/C2); a cron-refreshed feed (not live on request); calling liftie.info (no terms, reportedly blocks servers); paid feeds.

## D4 Offline map and terrain

`maplibre_gl` (the MapLibre organisation's Flutter plugin, v0.27, PMTiles and offline support on both platforms). The refresh cuts a basemap from Protomaps with `pmtiles extract --bbox` (ODbL) and terrain from Mapterhorn (Terrarium WebP PMTiles, mixed open sources credited in-app). The device loads both from local files with native hillshade. Expected size 5-25 MB per resort; F17 measures it. The skeleton proved a local-file PMTiles fixture renders on iOS and Android with networking off.

Fallback order if a platform fails: `mbtiles://` from a file, then the `maplibre` package (josxha), then `flutter_map`; if all fail, stop and reopen G1. Rejected: MapLibre offline regions from a third-party host (host terms, no per-resort sizing); AWS Terrain Tiles (XYZ PNGs to repack).

The app installs a start-up-safe map platform (`app/lib/map/start_up_safe_map_platform.dart`), a `MapLibreMethodChannel` subclass whose teardown does nothing until its channel has been opened. The plugin tears the platform down on any removal but assigns its channel only once the native view exists, so removing a map early threw `LateInitializationError`. The module's single `MapLibreMap` building point installs it, so every map runs on it, and it catches no error. Remove it once the plugin closes an unopened channel safely. Rejected: catching the error (hides real teardown faults); a vendored patched `maplibre_gl_platform_interface` (a fork to re-patch on every upgrade, and a later upgrade can drop the patch silently); installing in `main()` (Patrol never calls it) or in `SkimapperApp` (widget tests bypass it).

## D5 On-device storage

Each saved resort is a directory holding its manifest and parts; user state and the saved-resort index go in SQLite via `drift` (starting at migration 1 in F3, the first user state, or F16). The resort catalogue is the exception: the device keeps the served envelope byte-for-byte in one file in app support storage (written to a pending file, flushed, then renamed into place) and reopens it through the same `openDocument` as a network answer, so a corrupt, older or unknown-schema copy counts as nothing saved with no second version mechanism. Rejected: `sqflite` directly, Isar, Hive; saving the parsed resorts in the app's own format (a second version mechanism and a storage schema before any user state exists).

## D6 Routing

Our own Dijkstra/A* in Dart over a graph the daily refresh pre-builds and ships in the data part. Edges carry kind, difficulty, status key and time; F12-F14 filter or weight edges per request. Rejected: building the graph on the device; GraphHopper and Valhalla.

## D7 Test layers and E2E tooling

Fast: `flutter test` and the Worker's Vitest tests. Slow: Worker integration tests (Miniflare R2) and the sweep self-test. E2E: **Patrol** (Dart tests, find widgets by key or text, drive native UI on both platforms including Android's Wi-Fi and cellular toggles). Fallback if Patrol's native iOS runner cannot be made to work: Maestro. Rejected: Maestro as first choice (YAML, black box, depends on semantics identifiers); bare `integration_test` (cannot drive native UI such as the permission dialog in F2).

- E2E tests are grouped by the endpoint state they need (`app/patrol_test/<group>/`); the runner prepares each group's endpoint and seeds the curated catalogue per run. The one exception is `endpoint_scripted`, whose tests change the endpoint mid-run, so each test states its saved-state and endpoint-state preconditions at its start and never inherits another's.
- **Tests change the endpoint through a log-marker channel.** A test prints a tagged `[e2e-request]` line (`stop-endpoint`, `serve-catalogue <variant>`) and `tools/e2e` reacts with its own bash functions; a request is idempotent (log lines can repeat) and an unknown request or variant fails the run. `serve-catalogue` restarts the endpoint on a freshly seeded directory, not an in-place write to a running Miniflare. The watcher polls Patrol's output file while Patrol's PID is alive instead of reading a pipe, so it ends on Patrol's exit whatever Gradle daemons hold, and `ENDPOINT_PID` stays in the harness shell. After a request the test probes `/v1/catalogue` until the change is visible, with a timeout that fails visibly. Rejected: a host control HTTP server (a new process driving state the bash harness owns); an on-device fake server (the pull test would no longer hit the real Worker).
- **`clearPackageData` is off**, so an app relaunch inside a test keeps its saved copy; Patrol still uninstalls at each group boundary. A relaunch pair is two tests named `relaunch 1 of 2` / `relaunch 2 of 2`, because the iOS runner orders tests by name.
- The Worker has no separate unit layer yet: its Miniflare tests run in about a second, and an empty layer would trip the sweep's zero-test rule for no benefit.
- The sweep is Node TypeScript (`tools/sweep/`) with its self-test on Node's built-in runner so `tools/` needs no package install. It clears only `test-results/sweep/`, so TDD evidence and demo packs survive. Layers write straight to log files and the sweep ends on process exit, because Gradle and Kotlin daemons inherit a captured output pipe and stalled the first real sweep for 44 minutes.
- **The E2E run record is on the layer's stdout.** `tools/e2e` writes the endpoint's output, its own milestones (group start, endpoint ready, Patrol start and end) and an `lsof` snapshot of the endpoint port at each group's start and end. Every line carries a tag (and the group) and a UTC ISO-8601 millisecond timestamp, stamped as it arrives by one long-running `node` filter (`tools/lib/stamp-lines.ts`); the app's lines use the same format (`[app <time>]`, no group). The sweep already keeps and uploads that stdout, so there is no per-layer artefact directory; standalone runs keep it in the terminal only. The sweep's e2e test count is anchored to the line start so no captured line can look like Patrol's summary.
- **`ENDPOINT_PID` names the endpoint itself; stopping stops its whole tree.** The endpoint's output is prefixed through process substitution, never a pipe, and the stamper is opened from the harness shell before the fork, so it stays outside the endpoint's tree and records the last shutdown lines. `stop_endpoint` snapshots the tree once, before any signal (a parent that dies on SIGTERM would orphan its child out of reach: CI's wrangler/workerd shape), sends SIGTERM to exactly that snapshot, records the signalled PIDs as a harness milestone, then waits until every snapshotted PID has exited (a zombie counts as exited) and no LISTEN socket remains on the port (`port_holders`, the same predicate as the run record's port snapshots), up to `ENDPOINT_STOP_TIMEOUT_MS`. At the limit it fails visibly (a port snapshot and one `error:` naming the processes still running and the port holders) and does not escalate to SIGKILL, which would hide a hung stop. It clears `ENDPOINT_PID` first, so the stop an EXIT trap repeats is a no-op. Rejected: signalling a process group (needs job control and changes Ctrl-C delivery in dev-app); killing whatever holds the port (could kill a developer's own endpoint); a second wait limit. `start_endpoint` writes to stdout and its caller chooses the destination.
- **`start_endpoint` returns only once the catalogue route answers** (any status, any body), so a cold route's first answer is never the app's.
- **Debug-only diagnostics stay in.** Patrol builds debug, so the capture runs in E2E and release is unchanged: the app's launch line, a per-connection trace (lookup, connect), an event-loop lag watch for the first seconds, and, on iOS, the simulator's own networking log for the app, which is the one platform branch in `tools/`. They are why a first-launch stall on CI can be read from the log rather than guessed at.

## D8 Data-contract versioning

Every JSON document carries `kind`, `schemaVersion` (per kind) and `dataVersion`; binaries are pinned by hash in the manifest; `/v1/` versions the route layout only. A breaking change to one kind bumps that kind's `schemaVersion` and the endpoint keeps publishing the old version until old apps age out. The app checks versions in one place: an unknown version shows a visible "update the app" style error and keeps the saved copy. `openDocument` (beside the envelope in `contract_envelope.dart`) opens the envelope and runs the kind's parse, and gives one of three outcomes for network answers and saved copies alike: *understood* (the raw body and the parsed value), *incompatible* (a wrong kind or an unknown `schemaVersion`: the only case that means "update the app") and *failed* with its cause (a non-envelope body, or data the parse rejects). `EndpointClient` adds unreachable, timeout and any non-2xx to *failed*, so classification finishes, and is logged, in one place. Rejected: lumping non-2xx in with "update the app"; parsing the data after the client reports the answer reached (two homes for the classification). `EndpointClient` logs each fetch's start and outcome in debug builds (printing the outcome it classified, never re-classifying), and runs the fetch and its timeout in a background isolate so the outcome reflects the network and not a frozen UI isolate. Rejected: no versioning until F19 (earlier saved copies could only be deleted); ETags only (do not survive into saved copies).


CI's first app launch after each install freezes the UI isolate for seconds: MapLibre compiles its Metal shaders synchronously on the iOS main thread at its first draw, and with Flutter's merged platform/UI thread the Dart isolate shares it. The plugin's behaviour can't be changed, so anything with a timeout that must be honest runs off the UI isolate.

## D9 Home screen

The resort list is the home screen (area doc `definitions/resorts.md`), with the credits line in the scaffold's bottom bar. The fixture map below the list (the offline-map proof, its map line and the attribution) is scaffolding for the walking skeleton: F4 and F5 move or retire it, because the intended screen is the list alone, with a chosen resort opening its map. Rejected: the map scrolling away under the list (it would move the attribution off-screen).

## F1 Resort list

- **State is Riverpod, hand-written, without code generation.** Three providers (the endpoint client, the catalogue store and the resort-list notifier); `ProviderScope` sits inside `SkimapperApp`, so `main()` and Patrol (which pumps `SkimapperApp` without `main()`) both get one, and widget tests override the client and store. The user chose a state framework now, ahead of the shared list state F2-F4 need. Rejected: a plain `ChangeNotifier` with constructor injection (carries F1 alone, but the framework would be settled under F2-F4); `riverpod_generator` (adds build_runner to the TDD loop, CI and the sweep for three providers; hand-written and generated providers can coexist, so it can come later).
- **Request ordering is explicit in the notifier's apply step, not Riverpod's rebuild-on-refresh.** Each fetch gets a generation number; an answer older than the newest applied understood answer is dropped, whatever it is, and a saved copy read after any answer was applied is not shown. The launch answer is applied only after the saved copy, so a fast offline failure cannot beat the saved list to the screen. Saves are chained in applied order, so the newest lands last. Rejected: an `AsyncNotifier` refreshed with `ref.invalidateSelf`, whose "only the newest request counts" is the rule the spec rules out.
- **One shared accent and capitals fold** (`app/lib/text/fold.dart`: the `diacritic` package plus lowercasing, ties broken on the original string) orders the list now and F9's search later. Rejected: our own folding table.
- **A failed save still shows the new list.** It is reported through `FlutterError.reportError` and the debug run record; release builds have no signal until crash reporting exists, which is accepted at this scale because the flushed rename can only leave an older list, never a broken one. Rejected: a visible "couldn't save" message.
- **Glacier teal is the app's visual basis.** One theme (`app/lib/theme/app_theme.dart`, `appTheme()`) is passed to `MaterialApp`, and screens style themselves from its scheme and never use literal colours. The scheme is seeded from `#00687A`, chosen over an alpine blue and a pine green after the default Material look (purple buttons, a colourless list, notices that didn't stand out) was rejected. Content items are white raised cards on a `surfaceContainer` ground; notices over content are `primaryContainer` cards, tinted with the theme rather than amber so they read as information; full-area messages are an icon, heading and `FilledButton` with no card; snackbars float, so the credits sit in the scaffold's bottom bar instead of the snackbar carrying a hard-coded offset that F5 would break. Light only: F21 owns dark mode and contrast.

## Build-time choices

- **iOS uses Swift Package Manager, not CocoaPods**: Flutter 3.47 defaults to it and `maplibre_gl` and `patrol` ship SPM packages. The Patrol `RunnerUITests` target was added with the `xcodeproj` gem and links `FlutterGeneratedPluginSwiftPackage`.
- **JDK 25 (Corretto LTS) for Android**, the newest JDK Gradle 9.3.1 supports; `tools/lib/common.sh` resolves `JAVA_HOME` from `ANDROID_JDK_VERSION` in the dev config on the Android paths only (`e2e android`, `dev-app android`), so a stale shell value cannot break builds. On macOS it uses `java_home`; elsewhere (CI) it trusts `JAVA_HOME` and fails fast if its major version differs. No `if CI` branches in `tools/`.
- **Dev config is a sourceable `tools/dev.env`**, read directly by bash scripts and passed to the app with `--dart-define`.
- **The fixture tile is generated by `tools/fixtures/make_fixture_pmtiles.py`** (one z0 MVT tile, gzip, PMTiles v3) and committed; the camera sits at zoom 8 so a 20x20 query rect at the origin hits the polygon in both Android pixels and iOS points.
- **Worker tests use `@cloudflare/vitest-plugin`**, the renamed `@cloudflare/vitest-pool-workers` (the old name is deprecated and its last release needs Vitest 4).
- **Local seeding goes through `endpoint/scripts/seed-local.ts`**, which imports the artefact-layout module so the R2 key layout keeps one home.
- **iOS simulator is "iPhone 17"**, the newest unique iPhone name here; "iPhone 18 Pro" exists twice so a name lookup would be ambiguous.

## C5 Continuous integration

- **CI is thin workflows over the existing sweep.** `tools/full-sweep --layers <ids>` runs a subset of layers (`app`, `endpoint`, `self-test`, `e2e-ios`, `e2e-android`, owned by `sweepLayers`) and also writes `results.json`; `tools/sweep/report.ts` combines the files from several jobs against the expected layer ids, so a layer that never ran is red. Workflows hold no test command and no green rule (a self-test ratchet enforces it); "green" is `whyRed` per layer and one shared run-verdict predicate per run. Rejected: job conclusions as verdicts (restates the layer list and green rule in YAML, cannot see a layer that ran zero tests or a job that never started).
- **Runner topology.** arm64 macOS runners cannot nest virtualisation, so Android E2E runs on Linux with KVM and iOS on macOS. The sweep runs three parallel jobs (`linux`: app, endpoint, self-test; `android`; `ios`) then `report`. Rejected: fast layers and Android on one runner (Gradle and the emulator compete for memory).
- **Triggers.** `fast` (`push.yml`) runs on branch pushes (docs-only paths ignored) and on every PR to main with no path filter, so the required check always reports. The full sweep (`sweep.yml`) runs on each code push to main and on manual dispatch. Rejected: a nightly with a skip rule (budget-driven; the merge-commit sweep proves the same sooner); short-circuiting `fast` green on docs-only PRs (a green that ran nothing); a full sweep on PRs (E2E stays on demand).
- **No dependency caching.** Minutes are free, a warm Linux job saved about 30 s, and a cold run proves a clean build every time.
- **Pinned toolchains with one home each:** Flutter in `app/pubspec.yaml`, Node in `.nvmrc`, Patrol CLI and device names in `tools/dev.env`. CI overrides dev.env values only through the environment (e.g. `ANDROID_EMULATOR_FLAGS`).
- **CI's AVD uses the `pixel_7_pro` profile** (`ANDROID_AVD_DEVICE`): the SDK command-line tools define no newer one. Rejected: a committed custom `devices.xml`.
- **The Android job caps Gradle at 2 GB** beside the 4 GB emulator; kept as a guard.
- **The app layer pins `flutter test --reporter expanded`**, because Flutter's GitHub reporter output is not counted by the zero-test check.

## AC1 check matrix (C4)

Each decision against the constraints and criteria. Satisfies / unverified (feature that verifies it) / not affected.

| | 1 codebase | offline-first | routing on device | location on device | open daily sources | free tier | offline licence | storage/resort | routing perf |
|---|---|---|---|---|---|---|---|---|---|
| G1 Flutter | yes | via D4/D5 | Dart | yes | n/a | yes | BSD | n/a | AOT |
| G2/D1 Worker+R2+Actions | n/a | saved whole | n/a | never sent | daily | unverified until first deploy | n/a | 10 GB is about 400 resorts | n/a |
| D2 OpenSkiMap | n/a | yes | yes | n/a | yes | yes | unverified (F5/F20) | small | n/a |
| D3 live status | n/a | status optional offline | edge filter | yes | live | unverified (F6 CPU per resort) | unverified per site (F6) | none stored | n/a |
| D4 maplibre_gl + Protomaps + Mapterhorn | yes | local files | n/a | n/a | yes | no tile host | ODbL, open DEMs | unverified 5-25 MB (F17) | n/a |
| D5 dirs + drift | yes | yes | yes | yes | n/a | n/a | n/a | per-dir | n/a |
| D6 Dart Dijkstra | yes | yes | yes | yes | n/a | n/a | n/a | well under 1 MB | unverified (F11) |
| D7 Patrol | one suite | n/a | n/a | n/a | n/a | OSS | n/a | n/a | n/a |
| D8 envelope | n/a | updatable copies | n/a | n/a | yes | n/a | n/a | n/a | n/a |

Origin: C4 (spec and design deleted; see git history).
