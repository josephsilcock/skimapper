# C5 Continuous integration

## Intent

Today every test layer runs only on the developer's Mac. A change that passes only because of local
state (a cached build, a hand-configured simulator, a particular JDK) goes unnoticed, and nothing
checks the trunk between features. C5 runs the project's own test commands on GitHub, where the repo
is hosted. The cheap layers run on every push, so a break shows on the commit within minutes. The
whole sweep, E2E on both platforms included, runs nightly on the trunk, so it is proven on a clean
machine. CI **reports**; it never blocks a merge. The developer reads the result on GitHub and in
GitHub's failure email, and raises a bug when the trunk goes red.

The constraint that shapes everything is that the repo stays private (DECISIONS.md G3). That gives a
budget of 2,000 Actions minutes a month, with macOS minutes counted ten-fold. If the nightly sweep
doesn't fit, the recorded fallback is to make the repo public.

## Rules

- **One home for test commands.** CI invokes the same entry points as local work: `tools/full-sweep`,
  with a layer-selection switch that the sweep owns and that CI and local runs use identically, and
  the values in `tools/dev.env`. A run may override `tools/dev.env` values through the environment,
  which is the override mechanism dev.env already documents. Workflow files never restate a test
  command. `docs/PIPELINE.md` gains a CI row.
- **CI-only runner preparation may live in the workflow.** Creating the simulator or AVD on a clean
  runner, or installing toolchains, is a step only CI needs, so it lives in the workflow rather than
  `tools/`. It creates the devices that the run's config names.
- **Fast checks** are the PIPELINE.md fast row (`flutter test`, `npm test`) plus the sweep self-test.
  PIPELINE.md lists the self-test in the slow row; it is included here on purpose, because it takes
  seconds and it guards `tools/`.
- **Nothing that could not run counts as green**, across every job in a run and not only inside one
  sweep process. The sweep's existing rules apply unchanged: a layer that runs zero tests, or a
  device that cannot boot, is red and named. A job that never started shows its layers as red.
- **Where each layer runs.** The app, endpoint and sweep self-test layers run on Linux. Android E2E
  runs on a Linux runner with a hardware-accelerated emulator. iOS E2E runs on a macOS runner. The
  `tools/` scripts must therefore work on Linux as well as macOS. *(`/design-feature` confirms the
  runner facts first. If a macOS runner can boot the AVD after all, the design may take that simpler
  path for Android.)*
- **Full sweeps are never cancelled by pushes.** Push runs and full-sweep runs (nightly or manual)
  are cancelled independently of each other.

## Stage 1: fast checks on every push

> The developer pushes a branch, and sees a green or red check on that commit on GitHub, with the
> failing layer named and its log attached.

Stage 1 includes making `tools/full-sweep` start and run its non-E2E layers on Linux. Today the
shared tool setup assumes macOS (for example, it resolves `JAVA_HOME` with `/usr/libexec/java_home`
unconditionally).

```gherkin
Scenario: a code push runs the fast checks
  Given a push to any branch (trunk included) that changes code
  When CI runs
  Then the app tests, the endpoint tests and the sweep self-test run on a Linux runner
  And the commit shows a green check only if every one of them passed with at least one test

Scenario: a failing layer is named
  Given a push whose change breaks one layer
  When CI runs
  Then the check is red, the run names that layer, and the layer's log is attached to the run

Scenario: documentation-only pushes are skipped
  Given a push that changes only docs/, specs/, *.md files or .claude/
  Then no CI run starts

Scenario: a newer push supersedes an older one
  Given a push run in progress for a branch
  When a newer commit is pushed to the same branch
  Then the older push run is cancelled and only the newest commit gets a verdict

Scenario: the local sweep is unchanged
  Given the tools/ scripts after this change
  When the developer runs tools/full-sweep on their Mac with no layer switch
  Then it runs the same five layers in the same order, prints the same summary
  And exits with the same rule as before (zero only when every layer is green)
```

A docs-only push after a red code commit leaves the branch head with no check of its own. The red
stays visible on the earlier commit. This is accepted.

## Stage 2: nightly full sweep, and on demand

> Each morning the developer opens GitHub and sees the night's full-sweep result for the trunk,
> layer by layer, with the red layer's log attached, plus a failure email if it was red.

```gherkin
Scenario: the trunk is swept nightly
  Given the trunk's head is a commit that no nightly sweep has carried to a per-layer verdict
  When the nightly schedule fires
  Then all five sweep layers run (app, endpoint, sweep self-test, E2E iOS, E2E Android)
  And the run's summary lists all five layers with their results, with the sweep's logs attached

Scenario: unchanged nights are skipped, and the skip does not look like a pass
  Given a previous nightly carried the trunk's head commit to a per-layer verdict
  When the nightly schedule fires
  Then no sweep layer runs
  And that night shows no green sweep result

Scenario: a nightly that gave no verdict does not count as swept
  Given the previous nightly on the trunk's head was cancelled, never started,
    or failed before any layer reached a verdict
  When the nightly schedule fires
  Then the full sweep runs on that commit

Scenario: a job that never starts is red
  Given one of the nightly's jobs (for example the iOS or Android runner) does not start or finish
  When the run reports
  Then that job's layers are shown red and the run is red

Scenario: an E2E device that cannot start is red
  Given the runner cannot boot the simulator or emulator named in the run's config
  When the nightly sweep runs
  Then that E2E layer is red and the run names the device that failed

Scenario: the full sweep can be run on demand
  Given any branch
  When the developer starts the full sweep on it manually from GitHub
  Then the same five-layer sweep runs on that branch's latest commit
  And a manual run does not count as a nightly for the skip rule
```

**Skip rule.** A night is skipped when the trunk's head is a commit that a previous nightly carried
to a per-layer verdict, whether that verdict was green or red. A red commit that hasn't changed is
re-run only from the manual button.

**Acceptance of Stage 2** requires one real nightly to have run. The spec, and from `/finish-feature`
on DECISIONS.md, records the measured billed minutes per nightly against the budget. If that
measurement shows the nightly cannot fit, the going-public fallback is taken rather than the
schedule being silently thinned.

## Non-goals

- **No blocking or gating.** No required checks, branch protection or rulesets. Merges stay local.
- **No pipeline-skill changes.** `/finish-feature` neither pushes the feature branch nor waits for
  CI, and `/new-feature` does not check CI. The developer raises a red trunk as a bug.
- **No full sweep on push.** Every push, trunk included, gets the fast checks only. E2E runs nightly
  or on demand.
- **No deployment.** No Worker deploy and no secrets for Cloudflare or the app stores. CI needs no
  secrets.
- **Not the daily data refresh** (F20's cron) and not service monitoring (C3).
- **Going public is not part of C5**; it is only the fallback.
- **No retries or flake handling**, no test dashboards, and no notifications beyond GitHub's own.
- **No iOS anywhere but macOS**, and no change to the E2E tests themselves.

## NFR trigger

**Budget (cost).** Runners start clean, and `tools/e2e` builds once per test group, so a realistic
iOS E2E job is 20–40 minutes, which bills at 200–400 minutes. Add the Linux Android job and the
push runs, and that leaves roughly 4–8 code-changing nights a month inside 2,000 minutes. This
estimate is unmeasured, which is why Stage 2's acceptance requires a measured nightly (see above).
When minutes run out, GitHub refuses to start runs and says so on the run. That counts as visible.

**Shared minutes, accepted risk.** F20's future daily refresh cron will draw on the same allowance
(DECISIONS.md D1). If CI uses up the month's minutes, that refresh would stop until the month resets.
This is accepted while F20 is unbuilt. F20's spec must either reserve minutes or trigger the
going-public fallback.

**Security.** Workflows get read-only repository permissions and use no secrets. Third-party
actions are pinned.

## Simplification levers

- **Making `tools/` work on Linux is the main cost.** Part of it is unavoidable in Stage 1, because
  the sweep's entry point must start on Linux for the fast checks. The rest is Android E2E on a Linux
  KVM runner, which needs the emulator, the Android SDK and the JDK paths working on Linux. Lever:
  keep Android E2E local-only and give the sweep an explicit "android: not run on CI" outcome. That
  saves only the Android-specific part. Android is then never proven on a clean machine, and the
  lever bends the "nothing that could not run counts as green" rule.
- **Going public** removes the budget constraint and the skip rule; it is the recorded fallback. If
  it is taken, note G3's rule that GitHub disables a public repo's scheduled workflows after 60 days
  without activity.

## UX note

No app change. The developer sees the results on GitHub: the check on each commit, the Actions run
page (the per-layer summary and attached logs), the "Run workflow" button for the manual sweep, and
GitHub's failure email.
