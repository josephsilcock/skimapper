# C7 CI tooling nits

## Intent

C5's review left four rough edges in the sweep and CI tooling:
- a misused switch gives a bare crash;
- a local run of the CI report throws after it has already printed the table;
- the Android JDK check is tested only in its failing cases;
- nothing stops the full sweep's jobs from leaving out a layer or running one twice.

The goal is that misusing or extending the CI tooling fails clearly and early, never with a crash or a silent gap, and that the Android JDK check is tested both ways.

Demo sentence: *a developer does the following and sees each result.*
- They run `tools/full-sweep --layers` with no value, and see one `error:` line naming the switch and the valid layer ids.
- They run `node tools/sweep/report.ts <dir>` locally, and see the per-layer table, with the verdict as the exit code.
- They edit `sweep.yml` so a layer is dropped or run twice, and see the sweep self-test go red naming that layer.
- They briefly break the JDK check, and see its new passing-case test go red.

## Acceptance criteria

```gherkin
Scenario: a layer switch with a missing or empty value fails clearly
  Given the sweep or the CI report is run with `--layers` (or `--expect`) as the last argument,
    or with a value that is empty or has an empty item (`""`, `app,`, `,`)
  When it parses its arguments
  Then it prints one `error: …` line naming the switch and the valid layer ids, with no stack trace
  And it exits non-zero having run nothing (for the report: no table and no write to the summary file)

Scenario: the CI report runs locally
  Given GITHUB_STEP_SUMMARY is unset or empty
  When `tools/sweep/report.ts` combines a results directory
  Then it prints the per-layer table to stdout and writes no summary file
  And it exits 0 if every expected layer is green, otherwise 1

Scenario: the Android JDK check accepts the right JDK
  Given a non-macOS host whose JAVA_HOME holds the JDK version tools/dev.env names,
    reported in either the GA form ("25") or the update form ("25.0.1")
  When an Android path checks its JDK
  Then it continues without error

Scenario: the full sweep's jobs run every layer exactly once
  Given every job in `.github/workflows/sweep.yml` that runs `tools/full-sweep`
    (a call without `--layers` counts as every layer)
  When the sweep self-test reads the layers each job runs
  Then it fails, naming the layer, if any layer in `sweepLayers` is missing, runs in more than one job, or is not a known id
```

The JDK scenario is a **coverage ratchet**: the behaviour exists today, so no RED step is expected. `/implement` proves the test can fail by briefly breaking the check (for example, flipping its version comparison), watching the test go red, and then restoring the check.

## Non-goals

- **No change to `push.yml` or its `FAST_LAYERS`.** `fast` runs a subset on purpose, and `selectLayers` already rejects unknown ids at runtime.
- **No runtime duplicate handling in `runVerdict`.** The static job check is the guard, and there stays one run-verdict rule.
- **No change to `report.ts`'s output format or to what it reports.** Per-test browsing is C8.
- **No general argument parser.** A value that is itself a switch (`--layers --expect`) is already rejected as an unknown layer, and stays that way.
- **No special handling for a forgotten results directory.** `report.ts --expect app` with no directory shows every layer red with "no result". The reason it gives is misleading, but the run is red, so nothing passes silently.
- No new layers, workflow jobs or CI triggers.

## NFR trigger

None. This is developer tooling with no performance, security, data-volume, concurrency or migration implication.

## Simplification levers

Nothing stands out. Each item is a small change to existing tooling. The exactly-once job check costs most, because it reads each `tools/full-sweep` call's layers out of the workflow YAML. Relaxing it to coverage only would save little and would miss a layer that runs in two jobs. `runVerdict` uses the first result it finds, so that duplicate could be reported green.

## Design notes carried from the gate

- The local-run test must remove `GITHUB_STEP_SUMMARY` from the child process's environment explicitly. The self-test runs inside CI, where the variable is set, so an inherited environment would write a stray table into the real run's summary.
