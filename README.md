# SkiMapper

A ski resort map app for iOS and Android.

## Repository layout

| Path        | What                                                                                  |
|-------------|---------------------------------------------------------------------------------------|
| `app/`      | Flutter app (iOS + Android); unit tests in `app/test/`, Patrol E2E in `app/patrol_test/` |
| `endpoint/` | Cloudflare Worker serving stored artefacts from R2, with its tests                    |
| `tools/`    | Dev config (`dev.env`), dev-app, E2E runner, full sweep and fixture generator         |
| `docs/`     | All project documentation (see map below)                                             |
| `specs/`    | In-flight feature specs only — transient; merged into the docs and deleted at finish  |

## Running locally

`tools/dev-app <ios|android>` starts the local endpoint, boots the device and runs the app. Prerequisites and
every other command are in [docs/PIPELINE.md](docs/PIPELINE.md).

## Tests

`tools/full-sweep` runs every layer (app, endpoint, sweep self-test, E2E on iOS and Android); `--layers <id,…>`
runs a subset (ids `app`, `endpoint`, `self-test`, `e2e-ios`, `e2e-android`). CI runs it on GitHub. The command for
each individual layer is in [docs/PIPELINE.md](docs/PIPELINE.md).

## Documentation map

| Doc                                             | Role                                                                                         |
|-------------------------------------------------|----------------------------------------------------------------------------------------------|
| [docs/QUICK_START.md](docs/QUICK_START.md)      | Workflow, run commands, pattern cheatsheet                                                   |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)    | System design and core principles (decisions live in DECISIONS.md)                           |
| [docs/PIPELINE.md](docs/PIPELINE.md)            | The actual command for each pipeline role (tests, full sweep, dev app, trunk)                |
| [docs/BACKLOG.md](docs/BACKLOG.md)              | Bugs, suggestions, and future work (canonical F/B/C ids)                                     |
| [docs/CONVENTIONS.md](docs/CONVENTIONS.md)      | Naming and coding standards                                                                  |
| [docs/definitions/](docs/definitions/README.md) | **Area docs** — intended user-facing behaviour per product area; the definitive target state |
| [docs/DECISIONS.md](docs/DECISIONS.md)          | Decision log — why things are built this way, and the roads not taken                        |
| [docs/FEATURES.md](docs/FEATURES.md)            | Feature status index (one-liners)                                                            |
| [docs/TIDY_UPS.md](docs/TIDY_UPS.md)            | Opportunistic tidy-ups to fold into unrelated changes                                        |

## How work happens

Spec-first and TDD: a backlog item gets a spec in `specs/`, then a design (including its delta against
the area docs), each with approval, then RED → GREEN → REFACTOR. At finish, both merge into the area
docs and decision log and are deleted. The full workflow is encoded in `CLAUDE.md` and the `.claude/skills/` directory at the
repo root.
