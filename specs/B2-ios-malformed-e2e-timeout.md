# B2 iOS E2E "not understood" test times out on CI

## Intent

On CI's iOS simulator, `endpoint_malformed/endpoint_not_understood_test` fails: the 6 s wait for
"service response not understood" finds nothing. It passes locally. It is the last thing keeping the
iOS E2E layer red on CI, so a real iOS regression would be invisible against it. The goal is to find
the cause and fix it there, so that the layer is green on CI and stays green with margin. Lengthening
a timeout until it passes is not a fix.

## What is known

- There is one observed failure, in run 40007409887. The other two groups were green in the same
  job. Run 39160525305 never reached this group because B1's teardown failure stopped it first.
- Patrol reports only that 0 widgets carry the expected text. It does not record what the endpoint
  line showed instead.
- The harness discards the endpoint log: `tools/e2e` deletes its work directory on exit, and CI
  uploads only `test-results/sweep/`.
- The app's endpoint timeout is 3 s, and a timeout is reported as "service could not be reached"
  (DECISIONS.md, envelope decision). A first response that took 3–6 s would therefore show the wrong
  text. One that took more than 6 s would show "endpoint: loading".
- `tools/e2e` starts a fresh `wrangler dev` for each group. Its readiness probe hits `/` and never
  the R2-backed `/v1/skeleton/message` route. `endpoint_malformed` has a single test, so its fetch is
  both the first request to that endpoint's route and the first fetch of that app launch.
- On CI, every iOS test runs slower than locally. The unreachable test takes 4 s on CI and 1 s
  locally, which is roughly the 3 s timeout plus 1 s.

**Two competing hypotheses (neither confirmed):**

- **H1, cold endpoint route.** The first request to the freshly started local endpoint's R2 route is
  slow on the CI runner, so the app gives up at 3 s.
- **H2, slow first connection from the app or simulator.** The app's first connection stalls on CI
  even with nothing listening, as the unreachable test's timing hints. The cause might be the
  simulator's network stack, or the app's own cold start.

A host-side readiness fix would address H1 but not H2. The fix must not be chosen before the
diagnosis has distinguished them.

## Demo test

Surface-less: this is a harness or timing defect with no user-visible screen of its own. The
sentence is:

*"A developer dispatches the full sweep and sees the `e2e-ios` layer green, with all three groups
run, on two consecutive CI sweeps with no manual re-runs."*

The exemption is justified rather than assumed. What changes observably is the CI layer verdict, and
the sweep's per-layer results are the integration proof.

If the diagnosis finds an app fault (see Scope), the change becomes user-visible. Its sentence would
be *"a user whose first response is slow-but-valid sees the right endpoint line"*, and it gets a
demo-pack entry.

## Acceptance criteria

```gherkin
Scenario: A CI failure leaves evidence of what happened
  Given an iOS E2E group runs on CI
  When it finishes, pass or fail
  Then that group's endpoint log is kept under test-results/sweep/ and uploaded with the sweep
  And if a test fails, what the endpoint line showed at that moment is recorded in the log

Scenario: The cause is identified from CI evidence
  Given the not-understood test fails on a CI sweep with the capture in place
  When the failure is diagnosed
  Then the record states what the endpoint line showed when the wait expired
  And it separates endpoint-side latency (when the endpoint received and answered the request)
    from app-side latency (when the app sent the request and got the answer)
  And it names which hypothesis, or which other cause, the evidence supports

Scenario: The malformed endpoint is reported as not understood on CI's iOS simulator
  Given the local endpoint serves a body that is not an envelope
  When the app starts on CI's iOS simulator
  Then "service response not understood" appears within the test's existing 6 s budget

Scenario: The fix is proven on CI with margin
  Given the fix is on its branch
  When the full sweep runs twice in a row on CI
  Then the e2e-ios layer is green both times, reporting 5 tests (endpoint_serving 3,
    endpoint_stopped 1, endpoint_malformed 1), with each group's Patrol summary in its log
  And both runs are first attempts (run attempt = 1)
  And on both runs, the first /v1/skeleton/message response is under 1 s, both endpoint-side
    and app-side, as recorded in the TDD log
```

- **If it does not reproduce:** run up to **three diagnostic CI sweeps** with the capture in place.
  If the failure never recurs, B2 is **not** closed by two greens without a diagnosed cause. Work
  stops and the choice goes back to the user: close as "not reproduced" with the capture kept, or
  keep hunting.
- The diagnosis record (AC 2) lives in the design or TDD log. If the fix changes the harness
  contract, a one-line cause goes into DECISIONS.md or an area doc at sign-off.
- The final AC is judged on the `e2e-ios` layer only. The Android layer may still be red because of
  B3.

## Scope

- **Diagnostic capture is in scope and permanent:**
  - each group's endpoint log is kept under `test-results/sweep/`;
  - a failure-time record of the endpoint line is written to the log.

  It records only. It adds no assertions, so it does not breach the "no assertion changes" non-goal.
- **If the cause is in the harness or environment, fix it in the harness.** If readiness is changed,
  it checks only that the route answers, with any status and any body, and never what it serves. It
  applies only to groups that start an endpoint, so `endpoint_stopped` still sees no endpoint.
- **If the cause is a real app fault, fix it in B2**, as long as the fix stays within the
  endpoint-line behaviour. The fix adds a test at the right layer that fails against today's code.
  An app fault means one of these:
  - the app misreports or misclassifies a response that arrived within its 3 s timeout;
  - the app starts its fetch at a point where its own start-up makes it miss the 3 s budget.

  Slowness that comes from the simulator or runner rather than the app is a harness or environment
  matter.
- **Lever:** reproduce the *confirmed* cause locally, so that most fix iterations run on the dev
  machine. CI is then needed only for diagnosis evidence and the two proving runs.

## Non-goals

- **B3** (the Android E2E aborts after its first group because port 8787 is still held). It stays a
  separate item.
- **No change to the user-facing timing rules:**
  - the app's 3 s endpoint timeout (`ENDPOINT_TIMEOUT_MS`), locally or on CI;
  - the rule that a timeout means "service could not be reached";
  - the tests' 6 s "within seconds" budget.
- **No retries, skips or quarantine** of the test, and no re-running the job until it passes.
- **No app-side or test-side warm-up.** That means no extra request, no extra or reordered test, and
  no pre-launch that would hide a cold-start fault.
- No change to the E2E tests' assertions.
- No change to the endpoint line's wording or to the other endpoint outcomes.
- No general CI speed-up work (caching, runner size, simulator choice) unless the diagnosis shows it
  is the cause.

## NFR trigger

Latency headroom is the NFR: the first message response must come in well inside the app's 3 s
timeout on CI (under 1 s on the proving runs), not merely before it. There is no security,
data-volume or migration implication, and no production behaviour changes unless an app fault is
found.

## Simplification levers

- The cost driver is CI iteration: each iOS sweep takes about 15–20 minutes. Up to three diagnostic
  runs plus two proving runs are needed.
- **Taken:** reproduce the confirmed cause locally (see Scope).
- **Rejected:** one green instead of two, because a single pass proves little for a timing flake.
- **Rejected:** "it passes" without a confirmed cause, which the backlog entry itself rules out.
- **Rejected:** narrowing the CI dispatch to the iOS job, because the sweep's jobs already run in
  parallel and it saves no wall-clock time.
