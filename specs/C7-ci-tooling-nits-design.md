# C7 CI tooling nits — design

Spec: `specs/C7-ci-tooling-nits.md`. Developer tooling only: no UI sketch, no app or Worker change.

## 1. Reviewer summary

**Basis.** *Layer selection is one function of a command line.* The existing pair `listSwitch` + `selectLayers` (`tools/sweep/layers.ts`) becomes one function, `layersFromArgs`. It answers "which layers does this command line select" for the sweep, the report and the workflow check alike. It rejects a bad line by throwing a `UsageError`, and one CLI boundary turns that into a single `error:` line.

*Rejected:*
- (B) Patching each symptom where it sits, which leaves two parsers of "which layers a `tools/full-sweep` call runs" (main's and the workflow test's) to drift apart.
- (C) Moving the job topology into `layers.ts`, which only moves the YAML check, adds CLI surface, and takes C5's topology decision out of the workflow.

**Decisions**
1. **Every rejected layer list prints one line.** A list is rejected when it is missing, empty, has an empty item or names an unknown id. Each case prints one `error: <switch> …` line naming the valid ids, with no stack trace. An unknown id prints a stack trace today; the rule that rejects it is unchanged (spec non-goal). *Rejected:* fixing only the missing-value case, which leaves the stack-trace output the spec's intent is about.
2. **Selection throws; the entry point renders.** `layersFromArgs` throws `UsageError`. A boundary in a new `tools/sweep/cli.ts` (home of `UsageError` and the boundary) wraps each entry point's body. It catches only `UsageError`, writes the `error:` line and exits; anything else is rethrown, so a real fault keeps its stack. Both `main.ts` and `report.ts` use it from the first call site. *Rejected:* exiting inside the selection function, which would kill the in-process workflow check; and putting the boundary in `layers.ts`, which would put process I/O in a module that has none.
3. **A usage error exits 1, the same as Bash `fail`.** *Rejected:* exit 2 for the Node entry points only. It would separate "misused" from "red", but would split the rule between Node and Bash.
4. **The exactly-once check counts per `tools/full-sweep` call, not per job.** A *call* is a `run:` value, or a line inside a `run: |` block, whose first command word is `tools/full-sweep`; comments and prose are never calls. The check works in two steps:
   - The words after `tools/full-sweep` go to `layersFromArgs("--layers")`, where no switch means every layer.
   - Each `sweepLayers` id must then appear exactly once across all calls.

   An unknown id, or a value the plain text split can't read (quoted, `$VAR`), surfaces as `layersFromArgs`'s own unknown-layer error: red, and named. *Rejected:* parsing the YAML per job. Counting per call also catches a layer run twice inside one job. YAML parsing would need a package, and `tools/` takes no package install (D7).
5. **The workflow check is a coverage ratchet, like the JDK one.** `sweep.yml` is correct today, so the test passes when first written. `/implement` proves it can fail with three temporary `sweep.yml` edits: drop a layer, duplicate one, misspell one. Each must go red *for the right reason*: the message names that layer and says missing, twice or unknown. The file is then restored. *Rejected:* a check helper with permanent fixture-text tests (more test code to keep one YAML read honest).
6. **The report writes the step summary only when `GITHUB_STEP_SUMMARY` is set and non-empty**, and always prints to stdout. *Rejected:* defaulting to a local file (a new output the spec doesn't ask for).
7. **The `tools/full-sweep` subprocess test runs against a temp copy of `tools/`.** `repoDir` comes from `import.meta.dirname`, so in the copy `test-results` and every layer's `cwd` resolve inside the temp directory. If selection ever regressed to "run everything", the test would fail harmlessly. It would not delete the real `test-results/sweep/` (which `runSweep` clears first), and would not orphan a real `flutter test`. *Rejected:*
   - a results-dir override in `main.ts` (production surface added for a test);
   - a spawn timeout (it fires after the damage);
   - no full-sweep subprocess test (AC1's own demo sentence would go untested end to end).

**Guiding principles**
- `layersFromArgs` is the only place that reads a layer list off a command line. No caller or test re-splits a `--layers` or `--expect` value.
- An entry point runs nothing until its arguments are accepted. Selection comes before `runSweep` clears `test-results/sweep/`, and before the report writes anything.
- A tool that stops says why on one line starting `error:`, the same convention as Bash `fail`. `lastErrorLine` reads it from layer logs. For an entry point the reader is a human or the CI log.
- A self-test that spawns a tool removes `GITHUB_STEP_SUMMARY` from the child's environment, or points it at a temp file. It never inherits it.

**Risks / blast radius.** Every sweep and CI run passes through `layersFromArgs`, so a regression there breaks every job, loudly. With Decision 7 no test path can touch real results. *Unknowns:* none that could change the shape.

**Disproportionate complexity.** The exactly-once check is the only non-trivial part. Relaxing it to coverage only saves very little, and would miss a duplicate that `runVerdict`'s first match could report green. Lever: none.

**Not changing:**
- `push.yml` and `FAST_LAYERS`;
- `runVerdict`;
- the report's output format and its results-dir argument (`args.at(-1)`);
- the layer ids and their order;
- `require_given_jdk` itself;
- the jobs and triggers in `sweep.yml`.

Unrecognised arguments (for example `--layer app` or `--layers=app`) still run every layer. That is captured as a separate backlog item, not part of C7.

**Questions the gate ruled on:**
- Basis A over B and C.
- Decisions 1, 2, 4, 5 and 6 as written.
- Decision 2's boundary moved to `cli.ts`, following review.
- Decision 3: exit 1, not 2.
- Decision 7: a temp copy of `tools/`, chosen over a results-dir override or dropping the test.
- Unrecognised-argument rejection deferred to a new backlog item.
- Review fixes folded in:
  - the register additions;
  - the reworded `error:` principle;
  - an unknown-id subprocess case for the report;
  - a per-form AC3 break;
  - AC3 as the last slice;
  - the D7 citation.

## 2. Basis, then decomposition

**A — one selection function, one CLI boundary (chosen).** Each concept has one owner:
- `sweepLayers` owns the ids and their order.
- `layersFromArgs(layers, args, switch)` owns how a command line maps to layers. No switch selects all; otherwise it takes the comma list, in sweep order. Anything else gets a `UsageError` naming the switch and the ids.
- The `cli.ts` boundary owns turning that error into the `error:` line and exit 1.

How the ACs fall out:
- AC1 is the rejection path, reached through the boundary from both entry points.
- AC4 is `layersFromArgs` applied to each `sweep.yml` call, then counted, so "unknown id" comes for free.
- AC2 and AC3 are local fixes that don't touch the basis.

*What A makes hard:*
- The AC4 check reads shell words out of YAML with a plain text split. A call written with quoting or a variable reads as an unknown layer rather than being understood. That is visible, but anyone wanting a variable in `sweep.yml` has to change the check.
- The AC1 full-sweep subprocess test needs a temp copy of `tools/` to be safe (Decision 7).
- It changes the call shape `sweep.test.ts` uses.

**B — patch each symptom where it sits.**
- `listSwitch` guards its own value, so it has to be given the ids for the message.
- Each entry point gets its own try/catch.
- The workflow test has its own regex for `--layers` values.

*What B makes hard:* two readers of "which layers a call runs", with the default-all rule restated in the test, and the error rendering copied into two entry points.

**C — the job topology lives in `layers.ts`.** Layers carry a CI job, and `sweep.yml` calls `tools/full-sweep --job <name>`, so exactly-once holds by construction. *What C makes hard:*
- The YAML still needs checking that each job name is called once, so the check moves rather than disappearing.
- It adds a CLI switch.
- It moves C5's topology decision out of the workflow.

**Decomposition (A).** What changes, by module:
- `layers.ts` gains `layersFromArgs`, which absorbs `listSwitch` and `selectLayers`, and stays free of I/O.
- New `cli.ts` holds `UsageError` and the boundary.
- `main.ts` and `report.ts` run their bodies through the boundary.
- `report.ts` guards its summary write.
- `workflows.test.ts` gains the exactly-once check.
- `toolchain.test.ts` gains the passing JDK cases.

**Seams**
1. **The `layersFromArgs` contract:** args in, layers or a `UsageError` out, no I/O. The in-process tests and the workflow check hang off it.
2. **The entry point's process surface:** stderr, exit code, stdout, the summary file. The subprocess tests hang off it.
3. **`sweep.yml` text in, one word list per call out** (Decision 4's definition of a call), then fed to seam 1.

## 3. Single-home register

| Business rule | Single home | Paths that consume it |
|---|---|---|
| The layer ids and their order | `sweepLayers` (`tools/sweep/layers.ts`) | `layersFromArgs`; the report's default expected set; the `workflows.test.ts` exactly-once check (**new consumer**); `sweep.test.ts`; `run-record.test.ts` |
| How a command line selects layers. Absent means all; otherwise a comma list. Missing, empty, empty-item and unknown are rejected, naming the switch and the ids. | `layersFromArgs` (`tools/sweep/layers.ts`) | `main.ts` `--layers` (and so `tools/full-sweep`, and `push.yml` `fast` via `$FAST_LAYERS`); `report.ts` `--expect`; the `workflows.test.ts` exactly-once check (**new consumer**, no test-side parse); `sweep.test.ts` (its call shape changes) |
| A usage error is one `error:` line and exits 1 | Node: the `cli.ts` boundary. Bash: `fail` (`tools/lib/common.sh`) | `main.ts`, `report.ts`; every `fail` caller |
| A tool reports why it stopped on one line starting `error:` | Bash `fail` (`tools/lib/common.sh`); the Node `cli.ts` boundary | **Producers:** `fail` and its callers (`require_given_jdk`, `require_platform`, `tools/e2e`, `tools/lib/devices.sh`, `tools/lib/endpoint.sh`); the `cli.ts` boundary. **Readers:** `sweep.ts` `lastErrorLine` (layer logs); a human or the CI log (entry points) |
| Every layer runs exactly once across `sweep.yml`'s `tools/full-sweep` calls | the `workflows.test.ts` exactly-once check | the `report` job in `sweep.yml`, which it guards against `runVerdict`'s first match (not restated in `runVerdict`, per the spec non-goal) |
| Write the step summary only when `GITHUB_STEP_SUMMARY` is set and non-empty | `report.ts` | the `report` job in `sweep.yml`; `push.yml` `fast`'s report step; local runs; `report.test.ts` (sets it for its child) |
| The Android JDK must be `ANDROID_JDK_VERSION` (major version, GA or update form) | `require_given_jdk` (`tools/lib/common.sh`) | `use_android_jdk` on the Android paths of `tools/e2e` and `tools/dev-app`; `toolchain.test.ts` |
| Run-level green | `runVerdict` (`tools/sweep/verdict.ts`), unchanged | `runSweep`; `report.ts` |

The `error:` prefix and exit 1 have two formatting homes, one per language. That is accepted; the shared contract is the prefix and the code.

## 4. Data / schema shape

None.

## 5. Test strategy

There is no app surface, so Patrol E2E does not apply. The outer test for each behaviour is a black-box subprocess of the real tool, on the sweep self-test layer.

**Misused switch (AC1).** Subprocess tests check the process surface:

| Command | Test setup |
|---|---|
| `tools/full-sweep --layers` (switch last) | run from a temp copy of `tools/` (Decision 7) |
| `report.ts --expect` (switch last) | a temp summary file |
| `report.ts --expect` with an unknown id | a temp summary file |

Each run must show:
- one `error:` line naming the switch and the ids;
- no stack frames;
- exit 1;
- for the report: no stdout table and an untouched summary file.

The value variants (`""`, `app,`, `,`) are in-process tests of `layersFromArgs`. They reach the process surface through the same boundary.

**Local report (AC2).** One subprocess with `GITHUB_STEP_SUMMARY` deleted from the env, and one with it empty. Each asserts the table on stdout and an exit code equal to the verdict.

**JDK accepts (AC3).** Bash subprocess cases for `"25"` and `"25.0.1"`. These are a ratchet, broken once per form so each is proven to fail for its own reason: for example, making the sed pattern require a `.` reddens the GA case; flipping the comparison reddens both.

**Exactly once (AC4).** A test over the real `sweep.yml`, as a ratchet (Decision 5).

No database is involved.

## 5a. Failure posture

Fail fast and visibly everywhere. All of these are developer-run commands or CI steps, and their failure is a red job with an `error:` line. Nothing runs in the background. Nothing is irreversible: no test path can reach the real `test-results/` (Decision 7). An unparseable `sweep.yml` call is accepted as a red self-test, not handled.

## 6. Definition delta

No area doc covers tooling (`docs/definitions/` has none), so there is no area-doc change. At finish:
- `docs/DECISIONS.md` § C5 gains a bullet on two points: a switch misuse is a one-line `error:` exiting 1, through one selection function and boundary; and the self-test checks that `sweep.yml`'s calls run each layer exactly once, using the sweep's own selection.
- The `docs/PIPELINE.md` full-sweep row stays as it is.
- C7 leaves `docs/BACKLOG.md`.

## 7. First slices

1. **Walking skeleton.** A developer runs `tools/full-sweep --layers` with no value. They see one `error:` line naming `--layers` and the valid ids; it exits 1 and nothing runs. The test runs from a temp copy of `tools/` and goes through `layersFromArgs`, the `cli.ts` boundary and `main.ts`.
2. **Second entry point.** A developer runs `node tools/sweep/report.ts --expect app, <dir>` and sees the same single line, with no table and no summary written. This proves the report goes through the same boundary.
3. **Local report.** A developer runs `node tools/sweep/report.ts <dir>` with no `GITHUB_STEP_SUMMARY`. They see the per-layer table, with the verdict as the exit code.
4. **Exactly-once check.** A developer edits `sweep.yml` to drop `endpoint` from the `linux` job, and sees the sweep self-test go red naming `endpoint`.
5. **JDK ratchet (last).** A developer briefly breaks the JDK check and sees its new passing-case tests go red, one break per version form.

## Slices

- [x] 1. A developer runs `tools/full-sweep --layers` with no value, and sees one `error:` line naming `--layers` and the valid ids; it exits 1 and nothing runs (ccda50d)
- [x] 2. A developer runs `node tools/sweep/report.ts --expect app, <dir>` (or `--expect` last, or an unknown id), and sees the same single line, with no table and no summary written (88007e9)
- [x] 3. A developer runs `node tools/sweep/report.ts <dir>` with no `GITHUB_STEP_SUMMARY`, and sees the per-layer table, with the verdict as the exit code (a0aa222)
- [x] 4. A developer edits `sweep.yml` to drop, duplicate or misspell a layer, and sees the sweep self-test go red naming it (65e47ea)
- [x] 5. A developer briefly breaks the JDK check, and sees its new passing-case tests go red, one break per version form (297ca3a)

## Decisions taken during implement

- A missing value, an empty value and an empty item share one message (`<switch> needs a comma-separated list of layer ids (ids: …)`); an unknown id gets its own (`<switch>: unknown layer '<id>' (ids: …)`). Rejected: a separate message per empty case, which says nothing more useful.
- `report.ts` moved onto `layersFromArgs` in slice 1's refactor (not slice 2), so `listSwitch` could be deleted at once rather than living on beside its replacement.

## Implement gate

Closed (coordinator rulings under `/run-pipeline`):
- (a) Demo output accepted (auto): matches the spec ACs; no UI, so no sketch comparison.
- (b1) Error wording accepted as written (auto).
- (b2) `report.ts` onto `layersFromArgs` in slice 1 accepted (auto): internal ordering, no behaviour change.

## Resume

All five slices closed: 1 (ccda50d), 2 (88007e9), 3 (a0aa222), 4 (65e47ea), 5 (297ca3a). Implement gate closed. Next: `/finish-feature specs/C7-ci-tooling-nits-design.md`. Seams as built: `layersFromArgs` (layers.ts), `UsageError` + `runCli` (cli.ts, wraps main.ts and report.ts), `addToStepSummary` (report.ts), `fullSweepCalls` (workflows.test.ts). Evidence logs in `test-results/tdd/C7/`. `node --test tools/sweep/` must run outside the sandbox (endpoint-stop binds a port).
