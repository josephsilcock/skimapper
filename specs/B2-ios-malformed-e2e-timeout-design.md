# B2 iOS E2E "not understood" timeout — design

Spec: `specs/B2-ios-malformed-e2e-timeout.md`. No UI surface (harness and diagnostics); no § 2a sketch.

## 1. Reviewer summary

**Basis.** Extend the existing owners and send all capture to the E2E layer's own stdout, which the
sweep already writes to `test-results/sweep/e2e (<platform>).log` and CI already uploads.

- `EndpointClient` gains a **fetch log**: a start line and an outcome line per fetch.
- The app logs its **launch time**.
- `tools/e2e` + `tools/lib/endpoint.sh` gain a **run record** on stdout, with every line
  timestamped and tagged: the endpoint's output, harness milestones, and port-holder snapshots.

The fix is not designed here. It follows the diagnosis, through a gated addendum.

Rejected:
- **A, a per-layer artefact directory handed down by the sweep.** It adds a new sweep → layer
  contract, a second results-dir home, and stale-run clearing, and AC1 doesn't need any of them.
- **B, a test-side recorder plus device-log bundle.** It edits test code, needs platform branches,
  and can't see fetches in tests that don't watch the line.
- **C, a loopback packet trace.** It needs sudo on CI and says nothing about app start-up.

**Evidence and hypotheses.** On CI, the unreachable test takes 4 s and locally 1 s. That is weak
evidence: `attribution_test`, which doesn't wait on the endpoint, also takes 4 s on CI, so test time
is dominated by launch and pump. The design therefore assumes nothing beyond the spec's H1 (cold
endpoint route) and H2 (slow first connection from the app or simulator; app start-up and simulator
network are separate halves). It adds one weakly supported candidate:

- **H3, lingering endpoint.** An earlier group's endpoint process outlives `stop_endpoint`, the B3
  mechanism on macOS.
- **What weakens it:** in the failing run, `ensure_port_free` passed and the next wrangler bound
  the port.
- **What the port snapshot adds:** whether any process held the endpoint port before a group
  started and after it stopped.

The capture must let the diagnosis separate all of these.

**Decisions** (grilling round 1 and the gate):

1. **Capture first, fix by addendum.** `/implement` builds the capture and proves its failure path
   locally. It then runs up to three diagnostic CI sweeps and writes the diagnosis into the TDD log.
   Then it stops with a fix proposal, which is appended to this doc and gated.
   - **Pre-approved exception: H1 confirmed.** A harness readiness probe on the message route
     (any status, any body) proceeds without a further gate. H1 counts as confirmed only when the
     endpoint log shows the first route request:
     - received promptly after app launch;
     - answered in more than 2 s;
     - with app-side connection not the delay (fetch start → endpoint receipt is short).
   - Rejected: re-gating H1 (a round-trip for a fix the spec sanctions).
   - Rejected: pre-designing H2/H3 fixes (the fix would come before the evidence).
2. **The app logs each fetch twice, in debug builds only.**
   - `EndpointClient` logs a **start line** (path, wall-clock start) and an **outcome line** (path,
     outcome, elapsed ms). For "unreachable" the outcome line also names the **transport cause**:
     refused/failed connection or timeout.
   - Both lines are gated by `kDebugMode`. Patrol builds debug, and release behaviour is unchanged.
   - Rejected: a test-side line recorder. It is blind to the serving group's first fetch, which
     happens in `attribution_test` and is needed for AC4.
   - Rejected: logging in release builds too.
3. **The fetch log is AC1's record of what the line showed.** The line's text is a pure function of
   the outcome (D9). A start logged with no outcome by failure time means the line showed
   "endpoint: loading". A positive record, not an inference from silence.
   - Rejected: a test-side wait helper that logs on timeout (a second mechanism, and edits to the
     test files).
4. **The app logs its launch time** (debug only), at the earliest point both `main()` and Patrol
   reach. That is `SkimapperApp`'s first build, because Patrol never calls `main()` (D4). This
   separates H2's app-start half (late fetch start after launch) from its network half (slow
   fetch → endpoint receipt or refusal).
   - Rejected: `main()` as ruled. It never runs under Patrol, so it would log nothing in E2E.
5. **The run record goes to stdout, tagged and timestamped.** `tools/e2e` writes:
   - the endpoint's output, prefixed per line;
   - its milestones: group start, port check, endpoint ready, Patrol start and end;
   - an `lsof` snapshot of the endpoint port at each group's start and end, taken before
     `ensure_port_free`.

   Every captured line carries one prefix (tag, group, timestamp), so it can never match the
   sweep's `Successful|Failed: N` count pattern or its `error:` pattern. Standalone runs keep the
   record in the terminal only.
   - Rejected: a per-layer artefact directory (candidate A above).
6. **The capture runs on both platforms, with Patrol's `--show-flutter-logs` always on.** There is
   no platform or CI branch in `tools/`. The Android emulator's own clock is an accepted
   correlation limit.
7. **The Worker is unchanged.** If wrangler doesn't log requests, or doesn't log one the client
   abandoned at 3 s, endpoint-side timing comes from a harness-side probe. Slice 1 checks this.

**Guiding principles.**

- **The capture records and never asserts.** No E2E test file, assertion or timeout changes.
- **`stop_endpoint` always targets the endpoint process.** The output prefix must not change what
  `ENDPOINT_PID` names (process substitution, not a pipe). The slice that adds it shows the port
  free after `stop_endpoint`. Otherwise the capture would cause H3.
- **The capture fails visibly, never silently.** A capture step that breaks fails the group with a
  message. An empty `lsof` result is a valid snapshot, not a failure.
- **Outcome classification has one home (D8).** The fetch log prints the outcome `EndpointClient`
  produced, plus which exception it caught, and never re-classifies.
- **One timestamp format, one clock.** Every app-side and harness-side timestamp is host wall-clock,
  UTC ISO-8601 to the millisecond.
- **No timing rule moves.** The 3 s app timeout, the 6 s test budget and timeout-means-unreachable
  are fixed (spec non-goals).

**Risks / blast radius.** The change is confined to `tools/e2e`, `tools/lib/endpoint.sh` (shared
with `tools/dev-app`), and debug-only log lines in `EndpointClient` and `SkimapperApp`. Release
builds are unchanged.

**Technical unknowns, all checked in slice 1:**

- whether `--show-flutter-logs` surfaces `debugPrint` on iOS under `patrol test`;
- whether wrangler logs each request, including an abandoned one;
- the bash-side millisecond source.

The failure may not recur in three sweeps; the spec's stop rule covers that.

**Disproportionate complexity.** AC4's app-side figure for the serving group is what forces the log
into the client. The lever (endpoint-side timing alone for that group) was offered and **declined**:
AC4 stays as written.

**Not changing:**

- E2E test files and assertions;
- the endpoint line wording;
- the 3 s / 6 s budgets;
- `stop_endpoint`'s kill logic (B3's, unless the diagnosis proves H3 and the addendum says so);
- the sweep, its results-dir layout and the CI workflow jobs (except the e2e count pattern's line
  anchor, amended in implement — see Seams);
- the Worker.

**Gate rulings.**

- Grilling round 1 accepted all seven recommendations.
- At the gate, the user chose **A′** (stdout run record) over A, which drops grilling answer 5's
  artefact directory.
- They accepted the fetch-start line, the launch timestamp and the transport cause, the
  `ENDPOINT_PID` principle, the evidence correction, the H1 threshold, the local failure-path proof,
  `kDebugMode` gating, the unchanged Worker, and all minor register/posture fixes.
- They kept AC4 as written.
- **Adjustment:** the launch timestamp is ruled "in `main()`", but sits at `SkimapperApp`'s first
  build because Patrol never calls `main()` (D4).

## 2. Basis, then decomposition

**A′ (chosen) — extend existing owners, one output stream.**

| Owner | What it gains |
|---|---|
| `EndpointClient` (already owns fetch and classification) | the fetch log |
| `SkimapperApp` (already the root both `main()` and Patrol pump) | the launch line |
| `tools/lib/endpoint.sh` (already owns the endpoint lifecycle) | prefixing the endpoint's output and the port snapshot |
| `tools/e2e` (already owns the group sequence) | the milestones |

The sweep is untouched: it already keeps and uploads the layer's stdout.

How the ACs fall out:

| AC | How it is met |
|---|---|
| AC1 | the layer log + the fetch log's start/outcome pair |
| AC2 | reading the launch line, fetch start, endpoint receipt/answer and outcome on one clock, in one file |
| AC3, AC4 | the addendum's fix, proven by two sweeps whose logs carry both latencies |

What it makes hard:

- **AC4's serving-group app-side figure, the weakest AC.** It holds only because the log is in the
  client.
- **The layer log gets noisy,** and its parsing relies on the prefix discipline.
- **Standalone runs keep no file.**
- **Correlation relies on the shared host clock,** which is weak on Android.

**A — per-layer artefact directory.** The same capture, written to files in
`test-results/sweep/<layer>/`, handed down by the sweep through an env var.

What it makes hard:

- a new sweep → layer contract;
- a second results-dir home (`test-results/e2e/` for standalone runs) that also needs clearing;
- the `results.json` naming hazard in `report.ts`;
- AC2's timeline is a join across files.

**B and C** are as rejected in § 1.

**Decomposition.**

```mermaid
flowchart LR
  app[SkimapperApp launch line] --> fl[flutter logs]
  ec[EndpointClient start + outcome lines] --> fl
  fl -- --show-flutter-logs --> patrol[patrol test]
  e2e[tools/e2e milestones + lsof] --> out[(layer stdout → sweep layer log)]
  ep[endpoint.sh: prefixed endpoint output] --> out
  patrol --> out
```

**Seams:**

- **App → log sink:** debug-only lines built from values the code already has. They never feed
  back into behaviour.
- **Harness → endpoint process:** the prefix wraps the output without changing which process
  `ENDPOINT_PID` names, and without parsing the output.
- **Layer stdout → sweep:** the sweep parses only the count pattern and the last `error:` line. Every
  captured line carries a prefix that matches neither. *(Amended in implement: the e2e count pattern
  was unanchored, so no prefix could hide a lookalike from it; it is now anchored to the line start.
  That one-line `layers.ts` change is the only sweep change.)*

The fix addendum hangs off these seams. An H1 probe lives inside `start_endpoint`.

## 3. Single-home register

| Business rule | Single home | Paths that consume it |
|---|---|---|
| Response → outcome (envelope, non-2xx, refused/timeout) (D8) | `EndpointClient._understand` / `_get`, `openEnvelope` | `SkeletonMessageLine`; **new:** the fetch log (prints the outcome and the caught exception, never re-classifies) |
| Outcome → endpoint line text (D9) | `SkeletonMessageLine` build switch | the placeholder screen; the diagnosis reads it from D9 (the harness never maps text) |
| App endpoint timeout (3 s) | `tools/dev.env` `ENDPOINT_TIMEOUT_MS` → `endpoint_dart_defines` → `devEndpointClient` | `tools/e2e`, `tools/dev-app`; unchanged; the local failure-path proof overrides it from the env only |
| Endpoint port / URL | `tools/dev.env` `ENDPOINT_PORT` → `ENDPOINT_URL` in `endpoint.sh` | `start_endpoint`, `ensure_port_free`, Android port forward, `tools/dev-app`; **new:** the `lsof` snapshot |
| Endpoint process identity (`ENDPOINT_PID`) | `start_endpoint` | `stop_endpoint` (via `tools/e2e` and `tools/dev-app`); **new constraint:** the output prefix must not change it |
| Capture line prefix and timestamp format (UTC ISO-8601, ms) | one bash helper in `tools/lib` (bash side, `node` as the ms source — macOS bash 3.2 and BSD `date` have none) and one Dart helper beside `EndpointClient` (app side) | endpoint output, milestones and `lsof` snapshots (bash); the launch and fetch lines (Dart); the sweep's count/`error:` parsing (`tools/sweep/layers.ts`, `sweep.ts`), which must never match it |
| Layer-log location and upload | the sweep (`runSweep`) and `sweep.yml`'s `test-results/sweep/` upload | unchanged; the run record rides on it |
| Message route path `/v1/skeleton/message` | Worker `documentRoutes` (`endpoint/src/index.ts`) | the app (`SkeletonMessageLine`); **if the H1 addendum applies:** the readiness probe in `endpoint.sh`, named once beside `ENDPOINT_URL` (accepted cross-language duplication, D7's existing pattern) |
| Readiness = "route answers, any status" (spec scope) | `start_endpoint` (only if H1) | every E2E group that starts an endpoint, and `tools/dev-app`; never `endpoint_stopped` |

## 4. Data / schema shape

None.

## 5. Test strategy

| Behaviour | Outer test |
|---|---|
| Fetch log: start and outcome lines for each outcome, with the transport cause for unreachable; silent outside debug | app unit test with a fake HTTP client (`flutter test`). It is surface-less, so the outer evidence is an E2E run whose layer log shows the lines, recorded in the TDD log. No E2E assertion is added |
| Launch line | app unit/widget test that pumping `SkimapperApp` logs it once |
| Run record (prefixed endpoint output, milestones, port snapshots, port free after `stop_endpoint`) | there is no bash test layer, so a real `tools/e2e` run is the integration proof, read into the TDD log. A bash test framework is not added (gold-plating at this scale) |
| Captured lines never trip the sweep's parsing | sweep self-test (`node --test tools/sweep/`): a layer output containing prefixed capture lines counts and reports exactly as without them |
| AC1 failure path | a local induced failure (a listener on the port that never answers, via the `ENDPOINT_PORT` / `ENDPOINT_TIMEOUT_MS` overrides, with no test edits), read into the TDD log before any CI sweep |
| Diagnosis (AC2) | the record in the TDD log from up to three CI sweeps |
| Fix (AC3, AC4) | the existing `endpoint_not_understood_test` on two consecutive first-attempt CI sweeps, plus the latencies read from the layer logs |

No path needs a real database.

## 5a. Failure posture

- **The capture is fail-fast and visible.** A missing tool fails the group with a message in the
  layer log, which the sweep already turns red. An empty `lsof` result is valid.
- **The fetch and launch logs have no failure mode worth handling.**
- **No reproduction:** if the failure doesn't recur in three sweeps, the spec's stop rule hands the
  choice back to the user. Two greens are never taken as the cause.

## 6. Definition delta

- No area doc exists for the harness, and `docs/definitions/` is empty, so there is none to change.
- At finish:
  - **D7** gains a line on the E2E run record (prefixed, timestamped, on the layer's stdout; the
    `ENDPOINT_PID` constraint).
  - **D8** gains a note that `EndpointClient` logs each fetch's start and outcome in debug builds.
  - The diagnosed cause goes in as a one-liner where the fix changes the harness contract.

## 7. First slices (indicative)

1. *A developer runs `tools/e2e ios endpoint_malformed` locally and sees, in the output, the app's
   launch line and a fetch start/outcome pair for `/v1/skeleton/message` ("not understood",
   elapsed ms), all on one timestamp format.* This is the walking skeleton through the app log seam
   and `--show-flutter-logs`. It settles the first unknown and checks whether wrangler logs
   requests, including abandoned ones.
2. *A developer runs `tools/e2e ios` and reads one timeline in the output: prefixed endpoint
   lines, milestones and port snapshots per group, interleaved with the app's lines. After each
   group the port snapshot shows the port free.*
3. *A developer points the app at a listener that never answers (env overrides only) and sees the
   failing run's output record a fetch start with no outcome, which is AC1's "loading" record, and
   the sweep still counts the tests correctly.* (next)
4. *A developer reads the diagnosis in the TDD log, naming H1, H2, H3 or another cause from up to
   three CI sweeps, and the work stops for the fix addendum, unless H1 meets its threshold.*

## Slices

- [x] 1. *A developer runs `tools/e2e ios endpoint_malformed` locally and sees, in the output, the app's launch line and a fetch start/outcome pair for `/v1/skeleton/message` ("not understood", elapsed ms), all on one timestamp format.*
- [x] 2. *A developer runs `tools/e2e ios` and reads one timeline in the output: prefixed endpoint lines, milestones and port snapshots per group, interleaved with the app's lines; after each group the port snapshot shows the port free.*
- [ ] 3. *A developer points the app at a listener that never answers (env overrides only) and sees the failing run's output record a fetch start with no outcome (AC1's "loading" record), and the sweep still counts the tests correctly.* (next)
- [ ] 4. *A developer reads the diagnosis in the TDD log, naming H1, H2, H3 or another cause from up to three CI sweeps; work stops for the fix addendum unless H1 meets its threshold.*

## Decisions taken during implement

- **The e2e layer's count pattern is anchored to the line start** (`/^\W*(?:Successful|Failed): (\d+)/gm`). The design said the prefix alone kept captured lines out of the sweep's parsing; that holds for `error:` (already line-start) but not for the unanchored count, and `--show-flutter-logs` also puts unprefixed app output in the stream. Anchoring is the fix at the parser, rather than making every source of output prefix-safe.
- **Harness lines are stamped by one long-running `node` filter per stream** (`tools/lib/stamp-lines.ts`), not a `date` call per line: each line is stamped as it arrives, so a burst isn't smeared by process start-up. Milestones and port snapshots go through the same filter.
- **`start_endpoint` writes to stdout; callers choose the destination.** `tools/e2e` leaves it on the layer's stdout; `tools/dev-app` redirects the call to its old `endpoint.log` (now stamped). Avoids a `/dev/stdout` reopen, which on Linux truncates the sweep's log file.

- **`Unreachable` carries its transport cause** (`connection failed: <message>` or `timeout after <ms> ms`) rather than the client logging from inside its catch blocks: the outcome line then prints one value the classifier produced, so the log can't disagree with the line. The cause is for the log only; nothing branches on it.
- **The launch line is in `SkimapperApp`'s `initState`** (the widget became stateful) rather than its `build`: logged once per mount, however often the root rebuilds.
- **Endpoint-side timing comes from wrangler's own request line** (`[wrangler:info] GET <path> <status> (<n>ms)`, written on completion), stamped by the harness: receipt = stamp − duration. No harness probe added. Whether wrangler logs a request the client abandoned is unverified locally; on CI, an app fetch start with no wrangler line for it by group end is itself recorded evidence.

## Resume

Slices 1–2 closed (app fetch log + launch line; harness run record with stamped endpoint output, milestones, port snapshots; e2e count anchored). Next: slice 3 — local induced failure (a listener on a spare port that accepts and never answers, `ENDPOINT_PORT`/`ENDPOINT_TIMEOUT_MS` env overrides only, no test edits) so the failing run records a fetch start with no outcome by the time the 6 s wait expires, and the sweep counts the failure. Then slice 4 — push the branch, dispatch up to three `sweep.yml` runs (`gh workflow run sweep.yml --ref bugfix/b2-ios-malformed-e2e-timeout`), read `sweep-ios` artefact's `e2e (ios).log`, write the diagnosis, and GATE (unless H1 meets its threshold). Evidence logs: `test-results/tdd/B2/`. Local baseline: fetch start → wrangler answer ~200 ms; refused also ~200 ms.
