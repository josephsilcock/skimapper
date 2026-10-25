# Features

Status index of committed features. **One line + status per entry — behavioural detail lives in the
area docs at [definitions/](definitions/README.md)** (linked per section below).

**Status:** `done` · `planned` · `deferred` · `in progress` — no status = `planned`

- Bugs and suggestions: [BACKLOG.md](BACKLOG.md)
- In-flight specs: [../specs/](../specs/README.md) (transient — merged into area docs at finish)

## Features

- **F1** Skiers browse the supported ski areas by name and country, refresh by pulling down, and keep the list without a signal — `done`

## Code

- **C4** Initial technical decisions and walking skeleton — `done`
- **C5** Continuous integration: fast checks on every push and PR, full sweep on every code push to the trunk — `done`

## Bugs

- **B1** Removing the map before it has finished starting no longer throws — `done`
- **B2** The iOS E2E "not understood" test passes reliably on CI, its cause found and fixed — `done`
- **B3** Every Android E2E group runs on CI: stopping the local endpoint frees its port — `done`
