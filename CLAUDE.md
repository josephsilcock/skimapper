This is the root of the Skimapper application. The user facing part of the project is a mobile application to plot routes when skiing.

- `docs/` — project documentation

## Key rules

- **TDD mandatory**: RED/GREEN/REFACTOR, **one test at a time** — verified RED (run it, watch it fail for the right reason) before any implementation; refactor on green; never batch tests then code. The full loop lives in the `implement` skill.
- **E2E tests mandatory**: implementation tbd
- **All test layers must pass before a feature is done**: every layer in the full sweep named in `docs/PIPELINE.md` (commands TBD until the stack is chosen). The fast tests are for the TDD loop only. Never report a task complete after running a subset; discuss pre-existing failures with me rather than ignoring or silently skipping a layer.
- **Follow the feature pipeline**: `/add-backlog-item` (capture) → `/new-feature` (level-1 spec: intent + Gherkin ACs + non-goals) → `/design-feature` (basis, decisions, guiding principles, seams, single-home register, UI sketch — no code plan) → `/implement` (TDD, vertical slices) → `/finish-feature` (sign-off + commit). Each step produces its artefact(s), runs an embedded adversarial review at its altitude, and gets approval before the next. Don't skip to code. These skills each carries their own gate protocol, pre-implementation review contract, and completion-report format. `/run-pipeline` chains all four in one session: grilling questions still go to me, but at each gate Claude judges whether approval is needed (criteria in that skill) and otherwise proceeds, showing its rulings.
- **Finish properly**: `/finish-feature` at sign-off (all layers, TIDY_UPS check, FEATURES.md + `docs/definitions/` updates, commit). Always commit completed work and merge it into the trunk without being asked. When merging, preserve the branch's commits.

## Scale

Early-stage personal project with few users. The default failure posture is fail fast, fail safe, fail visibly (see the `design-feature` skill § 5a); revisit this when the app is publicly released.

## Code quality principles

- **Single responsibility with reconciliation**: functions do one thing. Where a state change has side effects, prefer an idempotent shared service that reconciles peripheral systems into a consistent state (e.g. recomputing a route's derived data whenever its runs change) over per-handler wiring. Route through the owning domain's service from the *first* call site, not the second — waiting for the second means refactoring a published API later.
- **A spec'd business rule has one named home**: when a spec states a domain predicate or formula, name the single code location that owns it and have every path (offer vs accept, application code vs SQL, backend vs app) consume that. Never re-derive a rule at a call site.
- **Readability is the goal** — orchestrators read as a narrative of named steps at one altitude; isolate irreducible complexity behind an intention-revealing call; short functions; minimal boilerplate; comments only for a non-obvious *why*. Canonical guidance + exemplar in `docs/CONVENTIONS.md` § Method altitude & narrative flow and § Comments; **applied and enforced in the `implement` skill's refactor step**.

## Documentation

- `docs/QUICK_START.md` workflow + cheatsheet · `docs/ARCHITECTURE.md` system design and core principles · `docs/PIPELINE.md` the actual command for each pipeline role (tests, sweep, dev app, trunk) · `docs/CONVENTIONS.md` naming/coding standards
- `docs/FEATURES.md` feature tracker (one-liners + status) · `docs/definitions/` **area docs** — living requirements per product area, the definitive target state · `docs/DECISIONS.md` decision log (why + rejected alternatives) · `docs/BACKLOG.md` bugs/suggestions (delete when resolved)
- `docs/TIDY_UPS.md` opportunistic tidy-ups to fold in when touching files — read before editing existing code
