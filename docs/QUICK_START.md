# Quick Start

## Workflow

Every change goes through the feature pipeline, one skill per stage, each with its own approval gate:

1. `/add-backlog-item` — capture an idea, bug or code item in [BACKLOG.md](BACKLOG.md) with the next free ID.
2. `/new-feature` — level-1 spec in `specs/`: intent, Gherkin acceptance criteria, non-goals.
3. `/design-feature` — decisions, guiding principles, seams, where each business rule lives, definition delta.
4. `/implement` — vertical slices, TDD one test at a time (verified RED → GREEN → REFACTOR), a commit per slice.
5. `/finish-feature` — whole-change review, full sweep, area docs + [FEATURES.md](FEATURES.md) + [DECISIONS.md](DECISIONS.md), merge to `main`.

`/run-pipeline` chains stages 2–5 in fresh-context subagents. Before editing existing code, read [TIDY_UPS.md](TIDY_UPS.md).

## Commands

The full table, with prerequisites, is in [PIPELINE.md](PIPELINE.md). The everyday ones:

| Want to…                         | Run                                                        |
|----------------------------------|------------------------------------------------------------|
| See the app on a device          | `tools/dev-app ios` or `tools/dev-app android`             |
| Run fast tests while TDD-ing     | `cd app && flutter test` · `cd endpoint && npm test`       |
| Run one E2E group                | `tools/e2e ios endpoint_serving`                           |
| Prove a feature is done          | `tools/full-sweep` (every layer; results in `test-results/sweep/`) |
| Use a different device for a run | `IOS_SIMULATOR="iPhone Air" tools/e2e ios`                 |

Device commands must run outside the Claude sandbox. Dev settings (port, timeout, simulator, AVD, JDK) live in `tools/dev.env`.

## Cheatsheet

- **Where does X go?** Behaviour → `docs/definitions/`; why it's built that way → DECISIONS.md; system shape → [ARCHITECTURE.md](ARCHITECTURE.md); naming and style → [CONVENTIONS.md](CONVENTIONS.md).
- **New JSON document from the endpoint?** Envelope it (`kind`, `schemaVersion`, `dataVersion`) and open it on the app side only through `openEnvelope` (`app/lib/endpoint/contract_envelope.dart`) (DECISIONS.md D8).
- **New R2 key?** Add it to `endpoint/src/artefact-layout.ts`; never build keys elsewhere.
- **New E2E test?** Put it in the `app/patrol_test/<group>/` that matches the endpoint state it needs; a new state needs a new case in `tools/e2e`.
- **Map style?** Always local: no remote URLs in any style (ARCHITECTURE.md § Principles).
