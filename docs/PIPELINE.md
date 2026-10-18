# Pipeline

Commands for the pipeline to run. Device commands (simulator, emulator, `flutter`, Gradle, Patrol) must run outside the Claude sandbox; `npm` inside it needs `npm_config_cache=$TMPDIR/npm-cache`.

| Role                      | Command                                                                                                                                                                                                                           |
|---------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| fast tests                | `cd app && flutter test` and `cd endpoint && npm test` (the Worker has no separate unit layer yet, so `npm test` runs its Miniflare integration tests too — DECISIONS.md D7)                                                      |
| feature-scoped slow tests | `cd endpoint && npm run test:integration` and `node --test tools/sweep/`                                                                                                                                                          |
| feature-scoped E2E        | `tools/e2e <ios\|android> [group…]` (groups are the folders under `app/patrol_test/`)                                                                                                                                             |
| full sweep                | `tools/full-sweep` (layers: app, endpoint, sweep self-test, e2e ios, e2e android; clears and writes `test-results/sweep/`)                                                                                                        |
| results dir               | `test-results/` (gitignored; the sweep writes `test-results/sweep/`, TDD logs go in `test-results/tdd/<ID>/`, demo packs in `test-results/demo/<ID>/`)                                                                            |
| dev app                   | `tools/dev-app <ios\|android>` (starts the local endpoint, boots the device, runs the app)                                                                                                                                        |
| trunk                     | main                                                                                                                                                                                                                              |
| merge into trunk          | push the branch; `gh pr create --base main --fill`; wait for the required `fast` check; `gh pr merge --merge --delete-branch`; then `git checkout main && git pull --ff-only` (direct pushes to main are rejected by the ruleset) |                                                                                                                                                                              |

All ports, URLs, device names and timeouts come from `tools/dev.env`; any value can be overridden per run from the environment (e.g. `IOS_SIMULATOR="iPhone 99" tools/full-sweep`).
