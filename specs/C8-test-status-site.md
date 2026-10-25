# C8 Test status site

## Intent

Anyone, technical or not, can open one link and see what the automated tests check, whether they
passed on trunk's latest full sweep, and how that has changed over time. The driving use case is a
non-technical stakeholder working out what still needs testing by hand. Today the only view is the
per-layer table `tools/sweep/report.ts` writes to a GitHub Actions run summary, with per-test
results buried in uploaded artefacts that expire after 14 days: developer-facing, inside GitHub, and
with no history.

## Ground rules (all stages)

- **The wording is the test names.** Each test is shown by its own name; there are no behaviour IDs
  or annotations. Names are written for a stakeholder: what a skier (or the service) would be seen to
  do, with no code identifiers. S1 renames today's developer-facing names, and adds the naming rule
  to `docs/CONVENTIONS.md` as a reviewer checklist item (no mechanical check). The rename pass is done
  when its list of renamed tests has been reviewed.
- **Grouped by folder.** A test's folder is its layer plus its path below that layer's test root
  (for example "app / resorts", "app / endpoint", "endpoint / integration"); files at a layer's test
  root sit under the layer's name. E2E results appear separately under an `ios` and an `android`
  folder. A behaviour checked by both a widget test and an E2E test shows as separate lines. There is
  no mapping to product areas or features.
- **Every test appears.** Every test that exists at the tested commit appears, whether or not its
  layer reported it. A test with no result (its layer stopped early, crashed or never ran) says
  "no result this run" with the layer's reason: never shown as passed, never omitted. A skipped test
  is shown as skipped, never as passed.
- **One line, one test.** A line is identified by platform + folder + test name. Names are unique
  within a folder; a collision fails the publish visibly rather than merging two tests.
- **Relaunch pairs read as one line.** Tests split into `relaunch 1 of 2` / `relaunch 2 of 2` (D7,
  for iOS ordering) show as one line named with both parts' names joined, minus their
  `relaunch k of 2:` prefixes. It passes only if both parts pass, fails if either fails, and
  otherwise has no result. An unpaired part shows as its own line under its full name.
- **Published from trunk only.** Every completed full sweep on main publishes, from a push or a
  manual run, except a manual run with any non-default input (`withhold_job` other than `none`, or an
  `ios_simulator` override). Branch runs and `fast` runs never publish. The site states which trunk
  commit it describes and when that sweep ran. Docs-only merges trigger no sweep, so they appear at
  the next code merge.
- **Hosting:** GitHub Pages, public, no access control (the repo is already public). Readable
  without a GitHub account.
- **"Automation never checks":** one short hand-written, site-wide list kept in the repo (for
  example look and feel, real devices, real GPS on the mountain, app-store builds).
- **Retention:** each run's per-test results are kept indefinitely; failure output is kept for the
  latest run only.

## Stages

Epic exit criteria: S1-S3 are done. Each stage gets its own design and approval before it starts.

### S1 Latest run

> A stakeholder opens the site's link and sees every automated test in plain words, grouped by
> folder, with E2E results under `ios` and `android`, whether each passed on trunk's latest sweep and
> when that sweep ran, plus the "automation never checks" list.

```gherkin
Scenario: the latest trunk sweep is published
  Given a full sweep has completed on main
  When a stakeholder opens the site
  Then they see each test by name, grouped by its folder
  And each test shows whether it passed, failed or was skipped in that sweep
  And the page says which trunk commit was tested and when

Scenario: a test that failed is visible as failed
  Given a test failed in trunk's latest sweep
  When a stakeholder opens the site
  Then that test is shown as failed, and its folder shows it contains a failure

Scenario: a layer that stopped partway
  Given a layer of trunk's latest sweep reported some of its tests and then stopped
  When a stakeholder opens the site
  Then each of that layer's tests it did not report is shown as "no result this run", with the layer's reason

Scenario: a layer that reported nothing
  Given a layer of trunk's latest sweep was red without reporting any tests
  When a stakeholder opens the site
  Then every test in that layer is shown as "no result this run", with the layer's reason

Scenario: runs that do not publish
  Given a full sweep is run manually on a branch, or on main with a non-default input
  Then the site still describes trunk's latest published sweep

Scenario: the limits of automation are stated
  When a stakeholder opens the site
  Then they see the "automation never checks" list
```

### S2 History and flakiness

> A stakeholder opens a test and sees when it was first tracked, when it last failed, how often it
> failed recently and whether it is flagged flaky; they can open any past run and see the trunk
> version it tested and when.

**Flaky rule.** A test's *runs* are the published sweeps in which it passed or failed; sweeps where
it had no result or was skipped are left out entirely (they neither use up the window nor break
adjacency). The window is its last 20 runs, or all of them if fewer. A test is *flaky* when the
window holds one or more failures with a pass immediately on each side, both inside the window. The
flag is always shown beside the plain count, "failed k of the last n runs", with the real n.

"Tracked since" is the first published sweep that included the test, which for tests that predate
the site is not when they started running. Renaming a test starts a new history; the old name's
history stays viewable under that name.

```gherkin
Scenario: a test's history
  Given a test has run in several published trunk sweeps
  When a stakeholder opens it
  Then they see when it was tracked since, when it last failed, and "failed k of the last n runs"

Scenario: a test that occasionally fails is flagged
  Given a test's runs, in order, are a pass, a failure, then a pass, all within its last 20 runs
  When a stakeholder looks at it
  Then it is flagged flaky, beside its failure count

Scenario: a sweep with no result does not count
  Given a test passed, then had no result in one sweep, then failed, then passed
  When a stakeholder looks at it
  Then the no-result sweep is not counted in n, and the failure counts as having a pass on each side

Scenario: a past run stays viewable
  Given several trunk sweeps have been published
  When a stakeholder opens an earlier run
  Then they see that run's results, which trunk commit it tested and when
```

### S3 Developer drill-down

> A developer filters every test of trunk's latest sweep across all layers and platforms (for
> example, failed Android E2E tests) and sees each one's result, duration and failure output.

```gherkin
Scenario Outline: filtering the latest run
  Given trunk's latest sweep has tests of several statuses, platforms, layers and folders
  When a developer filters by <dimension>
  Then only the matching tests are listed, each with its result and duration
  And each failed test shows its failure output

  Examples:
    | dimension |
    | status    |
    | platform  |
    | layer     |
    | folder    |
```

## Non-goals

- **No "not covered" list.** The site does not say which behaviours have no automated test (backlog
  C12); the area docs remain the place to compare against by hand.
- **No coverage figure**: neither line coverage nor test counts nor trends (backlog C11).
- No behaviour IDs, test annotations or mapping of tests to product areas or features; grouping is
  by folder.
- No pairing of a widget test and an E2E test of the same behaviour into one line.
- No results from branch runs, PR runs or `fast`; no republishing on docs-only merges.
- No failure output for past runs; the drill-down covers the latest run only.
- No access control, no Cloudflare hosting, no dependence on C10.
- No change to what the sweep runs, its layers or its green rule; the GitHub run summary stays.
- No notifications (email, chat) about failures.

## NFR trigger

Data volume: one run per completed main sweep (a pending sweep superseded in the concurrency group
is not swept separately). Per-test results are small and kept indefinitely; failure output is kept
for the latest run only, which keeps the site well inside GitHub Pages' 1 GB published-size limit.
Ordering: two main sweeps run one after another (`sweep.yml` concurrency group), and "latest" means
the most recently completed published sweep; a run must never lose or overwrite another's history
(S2). Security: the site is public. Its content is drawn from the same sweep logs already public as
Actions artefacts of this public repo, so it adds no new exposure; that risk is accepted with no
scrubbing. No migration or performance implications.

## Simplification levers

None taken. If S3 runs long: link each failed test to its layer's whole log instead of showing its
own output (gives up per-test failure text). Also considered and declined: keep only the last ~50
runs (gives up "tracked since" beyond that); show relaunch pairs under their own names (gives up a
little readability).

## UX note

A static site, mobile-readable. The stakeholder view (folders and tests with their results, the
trunk commit and run time, the never-checks list) is the landing page; the drill-down (S3) is a
secondary view. Passed, failed, skipped and no-result must be distinguishable without colour alone.
