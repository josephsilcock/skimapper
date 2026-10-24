# B3 Android E2E stops after its first group because the endpoint port stays held

## Intent

On CI, the Android E2E layer runs only `endpoint_serving`. `tools/e2e` then aborts with
`something is already listening on http://127.0.0.1:8787` before `endpoint_stopped`, so
`endpoint_stopped` and `endpoint_malformed` have never run on Android CI. The layer is red and covers
only a third of its groups, so a real Android regression in the unreachable or not-understood paths
would go unseen. The goal: stopping the local endpoint really stops it, everywhere the tools use it,
so that every group runs and the Android layer is green on CI.

## What is known

The cause is confirmed from the run record, not guessed. In sweep run 40034325935 (Android job):

- `endpoint_serving` passed 3/3, and Patrol ended at 23:08:20.808.
- At group end (23:08:20.950), after `stop_endpoint`, `lsof` shows
  `workerd 3317 ... TCP 127.0.0.1:8787 (LISTEN)`.
- At `endpoint_stopped` group start (23:08:21.149), the same workerd PID still holds the port, and
  `ensure_port_free` aborts the run.

So a workerd descendant of the endpoint survives `stop_endpoint` on CI's Linux runner.
`stop_endpoint` signals only the endpoint process and its direct children (`pkill -P`). Whether
workerd is orphaned or just slow to exit is for the design to settle. On macOS (locally, and on the
iOS CI job) the port is free after every group. `tools/dev-app` uses the same start and stop, so it
can leave the same workerd behind on exit.

DECISIONS.md D7 states that the port is free after every group. On Linux it isn't.

## Demo test

Surface-less: this is a harness defect with no user-visible screen. The sentence is:

*"A developer dispatches the full sweep and sees the `e2e-android` layer green, with all three groups
run and every group-end port snapshot reading 'nothing holds port 8787'."*

The exemption is justified. What changes observably is the CI layer verdict and the port snapshots
in the run record, and the sweep's per-layer results are the integration proof. The self-test in
AC 2 is the local proof.

## Acceptance criteria

```gherkin
Scenario: Stopping the endpoint frees its port
  Given the harness has started the local endpoint
  When the harness stops it
  Then stopping returns only once nothing from the endpoint's process tree is running
    and nothing holds the endpoint port
  And the device, the device log and the harness are still running

Scenario: A descendant that outlives its parent is stopped too
  Given a stand-in endpoint whose grandchild holds the port, alive and still attached
    when stopping begins, and whose middle parent exits on SIGTERM (CI's observed shape)
  When the harness stops it
  Then nothing holds the port when stopping returns
  (this self-test fails against today's stop on the dev machine)

Scenario: An endpoint that will not stop fails visibly
  Given the endpoint port is still held when the stop's wait limit runs out
  When stopping gives up
  Then the run fails with a clear error naming the port holders
    (in the E2E run record; on stderr for dev-app)

Scenario: Every Android group runs on CI
  Given the fix is on its branch
  When the full sweep runs on CI
  Then the e2e-android layer is green, reporting 5 tests (endpoint_serving 3,
    endpoint_stopped 1, endpoint_malformed 1)
  And every group-end port snapshot reads "nothing holds port 8787"
```

- **One green CI sweep is the proof.** The failure is deterministic, not a timing flake.
- **A new failure is not absorbed.** `endpoint_stopped` and `endpoint_malformed` have never run on
  Android CI. If either fails on its own terms (for example B4's thin first-launch headroom, or a
  B2-style first-launch freeze on Android), work stops and goes back to the user rather than widening
  B3.

## Scope

- One stop rule, used by both `tools/e2e` and `tools/dev-app`: stopping the endpoint covers its whole
  process tree (the endpoint's processes only, never the device, device log or harness that share
  its process group), waits for the port to be free, and fails visibly if it isn't free within the
  limit.
- "Port free" means nothing holds the socket, the same check as the run record's port snapshot, so
  the stop and the record cannot disagree. (`ensure_port_free`'s answers-HTTP check is unchanged.)
- The wait limit is one new value in `tools/dev.env`, the home of every timeout.
- A self-test in `node --test tools/sweep/` with a stand-in endpoint that behaves like CI's workerd,
  RED against today's stop on the dev machine. It uses its own port, never `ENDPOINT_PORT`, so it
  never touches a developer's running endpoint.
- dev-app gets no test layer of its own; it shares the stop the self-test covers.
- When a failed stop exits and the EXIT trap stops again, the first error stays the one reported.
- At sign-off, DECISIONS.md D7's "the port is free after every group" bullet is changed to state the
  new rule.

## Non-goals

- **The harness never kills a process it didn't start.** `ensure_port_free` stays unchanged as the
  guard against another listener on the port (for example a running dev-app endpoint), and still
  aborts the run.
- **No B4 work** and no first-launch latency fixes on Android, even if a newly running group exposes
  one. That stops and comes back (see above).
- No retries, skips or re-runs of a group, and no reordering or merging of groups to avoid restarting
  the endpoint.
- No change to the E2E tests, their assertions, the app, or the endpoint Worker.
- No change to existing values in `tools/dev.env` (the port, timeouts, devices).
- No `if CI` or Linux-only branch in `tools/`: the same stop runs on every platform.
- No second proving sweep.

## NFR trigger

None of substance. The stop's wait limit adds at most a few seconds per group in the worst case.
There is no security, data-volume, concurrency or migration implication, and no production
behaviour changes.

## Simplification levers

- **Taken:** no diagnosis phase, because the run record already names the surviving process.
- **Taken:** one proving sweep instead of two, because the failure is deterministic.
- **Rejected:** having the harness kill whatever holds the port. It's simpler, but it could silently
  kill a developer's dev-app endpoint.
- **Rejected:** proving only on CI. TDD's RED step would then be a 20-minute sweep, with no lasting
  local guard.
