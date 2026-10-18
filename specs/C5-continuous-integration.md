# C5 Continuous integration

> **Amended during implement (2026-10-18).** Two facts this spec rested on changed. The repo is now
> **public**, so Actions minutes are free. Merging into `main` now **requires a pull request**
> (repository ruleset). Rulings: no nightly schedule, so the skip rule is gone. Fast checks run on
> branch pushes and on PRs to main. The full sweep runs on every push to main and on demand. `fast`
> becomes a required check on PRs to main. Caching is dropped. The budget sections are removed.

## Intent

Today every test layer runs only on the developer's Mac. A change that passes only because of local
state (a cached build, a hand-configured simulator, a particular JDK) goes unnoticed, and nothing
checks the trunk between features. C5 runs the project's own test commands on GitHub, where the repo
is hosted.
- The cheap layers run on every branch push and every pull request to `main`, so a break shows
  within minutes.
- The whole sweep, E2E on both platforms included, runs on every push to `main`, which means on
  each PR's merge commit. It also runs on demand on any branch. The trunk is proven on a clean
  machine after every merge.
- The fast checks gate the merge. They are a required status check on PRs to `main`. The full
  sweep only reports.
- The developer reads the results on GitHub and in GitHub's failure email, and raises a bug when
  the trunk goes red.

The repo is public (DECISIONS.md G3 is superseded), so Actions minutes are not a constraint.

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
  `tools/` scripts must therefore work on Linux as well as macOS.
- **A running full sweep is never cancelled.** Fast-check runs and full-sweep runs are cancelled
  independently of each other. A queued full sweep on `main` may be replaced by the sweep for a
  newer `main` commit. Only the newest queued commit is swept.

## Stage 1: fast checks on every branch push and pull request

> The developer pushes a branch or opens a PR, and sees a green or red `fast` check on GitHub, with
> the failing layer named and its log attached. A PR to `main` can't merge until `fast` is green.

Stage 1 includes making `tools/full-sweep` start and run its non-E2E layers on Linux. Today the
shared tool setup assumes macOS (for example, it resolves `JAVA_HOME` with `/usr/libexec/java_home`
unconditionally).

```gherkin
Scenario: a code push to a branch runs the fast checks
  Given a push to any branch other than main that changes code
  When CI runs
  Then the app tests, the endpoint tests and the sweep self-test run on a Linux runner
  And the commit shows a green check only if every one of them passed with at least one test

Scenario: a pull request to main runs the fast checks
  Given a pull request into main, including one that changes only documentation
  When CI runs
  Then the fast checks run on the PR's merge result and report the `fast` check on the PR

Scenario: a failing layer is named
  Given a push whose change breaks one layer
  When CI runs
  Then the check is red, the run names that layer, and the layer's log is attached to the run

Scenario: documentation-only pushes are skipped
  Given a push (to a branch or to main) that changes only docs/, specs/, *.md files or .claude/
  Then no CI run starts for that push

Scenario: a newer push supersedes an older one
  Given a fast-check run in progress for a branch
  When a newer commit is pushed to the same branch
  Then the older run is cancelled and only the newest commit gets a verdict

Scenario: the local sweep is unchanged
  Given the tools/ scripts after this change
  When the developer runs tools/full-sweep on their Mac with no layer switch
  Then it runs the same five layers in the same order, prints the same summary
  And exits with the same rule as before (zero only when every layer is green)
```

A docs-only push after a red code commit leaves the branch head with no check of its own. The red
stays visible on the earlier commit. This is accepted. A docs-only *PR* still runs the fast checks,
so the required `fast` check always reports.

**Required check.** After C5's PR merges, the user adds `fast` as a required status check in the
`main` ruleset. Until then, no branch cut from `main` produces the check.

## Stage 2: full sweep on every push to main, and on demand

> After a PR merges, the developer opens GitHub and sees the full-sweep result for that merge commit,
> layer by layer, with the red layer's log attached, plus a failure email if it was red.

```gherkin
Scenario: every code push to main is swept
  Given a push to main that changes code (normally a PR's merge commit)
  When CI runs
  Then all five sweep layers run (app, endpoint, sweep self-test, E2E iOS, E2E Android)
  And the run's summary lists all five layers with their results, with the sweep's logs attached

Scenario: a job that never starts is red
  Given one of the sweep's jobs (for example the iOS or Android runner) does not start or finish
  When the run reports
  Then that job's layers are shown red and the run is red

Scenario: an E2E device that cannot start is red
  Given the runner cannot boot the simulator or emulator named in the run's config
  When the sweep runs
  Then that E2E layer is red and the run names the device that failed

Scenario: the full sweep can be run on demand
  Given any branch
  When the developer starts the full sweep on it manually from GitHub
  Then the same five-layer sweep runs on that branch's latest commit
```

**Acceptance of Stage 2** requires a real full sweep from a push to `main` (C5's own merge commit).

## Non-goals

- **The full sweep gates nothing.** Only `fast` is required. Android E2E is red until B1 is fixed,
  and a required sweep would block every merge.
- **No pipeline-skill changes in C5.** The PR merge route was changed by the user outside C5
  (CLAUDE.md, PIPELINE.md "merge into trunk", and the skills). `/finish-feature` doesn't wait for
  the full sweep on `main`.
- **No full sweep on branches or PRs** unless it is started manually. E2E runs on `main` pushes or
  on demand.
- **No schedule** (no nightly run), and no dependency caching.
- **No deployment.** No Worker deploy and no secrets for Cloudflare or the app stores. CI needs no
  secrets.
- **Not the daily data refresh** (F20's cron) and not service monitoring (C3).
- **No retries or flake handling**, no test dashboards, and no notifications beyond GitHub's own.
- **No iOS anywhere but macOS**, and no change to the E2E tests themselves.

## NFR trigger

**Cost.** None: the repo is public, so standard runners are free. The Android-on-Linux and
iOS-on-macOS split is a capability fact, not a budget choice. arm64 macOS runners can't run an AVD.

**Security.**
- The repo is public, so CI logs and artifacts are public too. CI uses no secrets.
- Workflows get read-only repository permissions.
- Third-party actions are pinned.
- PRs use the `pull_request` event, never `pull_request_target`, so a fork's PR gets a read-only
  token.

## Simplification levers

- **Making `tools/` work on Linux is the main cost.** Part of it is unavoidable in Stage 1, because
  the sweep's entry point must start on Linux for the fast checks. The rest is Android E2E on a Linux
  KVM runner, which needs the emulator, the Android SDK and the JDK paths working on Linux. Lever:
  keep Android E2E local-only and give the sweep an explicit "android: not run on CI" outcome. That
  saves only the Android-specific part. Android is then never proven on a clean machine, and the
  lever bends the "nothing that could not run counts as green" rule.

## UX note

No app change. The developer sees the results on GitHub:
- the `fast` check on each branch commit and PR;
- the Actions run page for each `main` merge (the per-layer summary and attached logs);
- the "Run workflow" button for the manual sweep;
- GitHub's failure email.
