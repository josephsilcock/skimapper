# B3 design: stopping the endpoint stops its whole tree

Spec: `specs/B3-android-e2e-endpoint-port.md`.

## 1. Reviewer summary

**Basis.** Three concepts:
- the endpoint's process tree, found at stop time by walking down from `ENDPOINT_PID`;
- one port-holders predicate (`port_holders`: `lsof` for a LISTEN socket on the endpoint port),
  shared by the run record's snapshot and the stop's wait;
- one stop wait limit in `tools/dev.env`.

The stop signals the tree, waits for the tree to exit and the port to be free, and fails visibly at
the limit.

*Rejected (kept as the named fallback):* starting the endpoint in its own process group and
signalling the group. It needs bash job control in a non-interactive script. In dev-app wrangler
reads the terminal, so it would get SIGTTIN unless its stdin were redirected. Ctrl-C delivery would
change, and the start-up plumbing would be reshaped, for a case nobody has seen.

**Decisions**
1. **The tree is snapshotted once, before any signal, and never walked again.** A recursive
   `pgrep -P` walk from `ENDPOINT_PID` collects the tree, then every snapshotted PID gets SIGTERM.
   Taking the snapshot first catches CI's shape, where the middle parent dies on SIGTERM and its
   child is reparented. *Rejected:* today's direct-children `pkill -P`; killing whatever holds the
   port (a spec non-goal); walking again on each poll.
2. **At the limit the stop fails without escalating.** There is no SIGKILL. The stop writes a
   stamped port snapshot, then fails with a one-line `error:` naming the holders' PIDs and commands,
   and exits 1. *Rejected:* SIGKILL followed by a second wait, which hides a hung stop and adds a
   second `dev.env` value.
3. **The wait limit is `ENDPOINT_STOP_TIMEOUT_MS=5000` in `tools/dev.env`**, overridable from the
   environment and in milliseconds like `ENDPOINT_TIMEOUT_MS`. A healthy stop returns as soon as the
   tree has exited and the port is free. *Rejected:* 10 s or more; a `_S` unit, which would mix units
   in `dev.env`.
4. **The stop records the PIDs it signals** as one stamped harness milestone: beside the port
   snapshots in E2E, and as one line on exit in dev-app. *Rejected:* a silent stop, which would leave
   a red CI run to guesswork.
5. **The stop clears `ENDPOINT_PID` before it waits**, so a second stop after a failed one is a
   silent no-op. `tools/e2e`'s EXIT trap removes the work dir *before* it stops the endpoint, so a
   stop failing inside the trap no longer leaks the work dir. If an earlier error has already
   exited, a failing trap stop may add a second `error:` line. That is accepted as extra evidence:
   the exit status stays 1 and the original error is still printed first.
6. **The endpoint's output stamper sits outside the endpoint's tree.** `start_endpoint` opens the
   stamper from the harness shell (a file descriptor opened before the fork) rather than as a
   redirection expanded inside the endpoint's fork. The walk therefore never signals the harness's
   own stamper, the endpoint's last shutdown lines survive, and the PID line lists only endpoint
   processes. *Rejected:* letting the walk signal the stamper.
7. **The self-test drives the real `stop_endpoint` against a stand-in tree, never wrangler.** It
   sources `tools/lib/endpoint.sh` in bash with its own `ENDPOINT_PORT` and a short limit. The
   stand-in uses the same stamper plumbing as the real start. Real wrangler is proven by a local
   `tools/e2e` run (no regression) and the CI sweep (the fix). *Rejected:* real wrangler in the
   self-test, which needs an `npm install` there and makes the layer slow.

**Guiding principles**
- One stop rule for every caller and platform: `stop_endpoint`, with no `if CI` and no platform
  branch.
- The stop signals only PIDs in its own snapshot. It never signals a process group, and never a
  port holder outside that snapshot.
- "Holds the port" has one meaning: `port_holders`, a LISTEN socket on `ENDPOINT_PORT`. The run
  record's snapshot and the stop's wait both consume it. `ensure_port_free` (answers HTTP) asks a
  different question and stays as it is.
- A PID counts as exited when it is gone or a zombie (`ps -o stat= -p`, which reads the same on BSD
  and procps). `ENDPOINT_PID` is reaped after the wait, never with a `wait` that has no limit.
- Every new *limit* lives in `tools/dev.env`. Poll intervals stay hard-coded, like
  `start_endpoint`'s `sleep 0.5`.

**Risks / blast radius.** The change is limited to `tools/lib/` and the trap order in `tools/e2e`.
A group ends up to 5 s later only when the run is about to fail. dev-app now needs `lsof`, which
ships with macOS. The run record's port snapshots change to listeners only.

The walk is hit by errexit: `pgrep -P` exits 1 on a leaf, so each call needs a guard. dev-app's
Ctrl-C is an accepted risk. The terminal sends SIGINT to the whole foreground group, endpoint
included, before the trap's stop, so the walk may find a partly dead tree. The wait on the port
still covers it, and a workerd that won't exit gets the limit and a visible error.

**Technical unknowns.** (a) Whether wrangler's tree on Linux is still attached when the stop begins.
The one CI sweep settles it through the signalled-PIDs line and the group-end snapshot. If workerd
escaped the walk, that is a STOP back to the user, with the process-group basis as the fallback.

**Spec requirement driving disproportionate complexity.** None. The "fails visibly" AC costs one
loop bound and one message.

**Not changing.** `ensure_port_free`, the E2E tests, the app, the Worker, existing `dev.env` values,
group order, and the sweep's layers and counts. `start_endpoint` changes only in how it attaches the
stamper (decision 6).

**Gate rulings.**
- Basis A was chosen, with B as the named fallback.
- Grilling: no SIGKILL; a 5 s limit as one `dev.env` value; signalled PIDs recorded.
- The gate accepted decisions 1 to 7 and the review findings: stamper outside the tree; LISTEN-only
  for both consumers; trap order and the second-error acceptance; dev-app Ctrl-C as an accepted risk
  with a manual slice; snapshot once; zombie-aware wait and reaping; `port_holders` in `endpoint.sh`
  with failure rendered as snapshot plus error; slice wording.
- Declined: running wrangler's binary directly instead of `npx` (out of scope; the walk covers it);
  a grep ratchet on `lsof` and `kill` (no unrequested enforcement).

## 2. Basis, then decomposition

**Candidate A, the walked tree (chosen).**
- *Concepts:* the endpoint tree (owned by `stop_endpoint`), the port holders (owned by
  `port_holders`) and the stop limit (owned by `dev.env`).
- *AC1:* the stop returns only when every snapshotted PID has exited and no listener remains. The
  device, the device log and the harness were never in the snapshot.
- *AC2:* the snapshot is taken before the middle parent dies.
- *AC3:* the loop bound, plus a snapshot and an error built from the port holders.
- *AC4:* this stop running in `tools/e2e` on CI.
- *What it makes hard:* AC2's boundary. A descendant that left the tree before the stop began is
  invisible. That is the case the spec's "still attached when stopping begins" leaves out, and the
  case dev-app's Ctrl-C approaches.

**Candidate B, the endpoint's own process group (fallback).**
- *Concepts:* an endpoint process group created at start through job control, with the port holders
  and the limit as in A.
- *AC1:* the stop signals `-PGID`, and the device and the harness are in another group.
- *AC2:* holds whatever the timing.
- *What it makes hard:* start-up. Job control leaves a background job's stdin attached, so wrangler
  gets SIGTTIN in dev-app; the terminal's Ctrl-C no longer reaches the endpoint; and a child that
  calls `setsid` still escapes.

**Decomposition.**
- `tools/lib/endpoint.sh`:
  - `port_holders` (new; LISTEN-only, carries the `lsof` presence check with a message that isn't
    specific to E2E);
  - `stop_endpoint`: snapshot, then signal, then record, then wait, then fail;
  - `start_endpoint`: the stamper attached from the harness shell.
- `tools/lib/run-record.sh`: `record_port_holders` consumes `port_holders`.
- `tools/dev.env`: one new value.
- `tools/e2e`: the trap order.
- A new self-test file in `tools/sweep/`.

**Seams.**
1. `ENDPOINT_PID` is the only link between start and stop. The self-test hangs off it.
2. `ENDPOINT_PORT` and `ENDPOINT_STOP_TIMEOUT_MS` reach the stop only through `dev.env`'s
   environment overrides, which is how the self-test isolates itself.
3. `port_holders` separates deciding whether the port is held from recording who holds it.

## 2a. UI sketch

None: this is a tooling-only change with no user-visible surface.

## 3. Single-home register

| Business rule | Single home | Paths that consume it |
|---|---|---|
| Who holds the endpoint port: a LISTEN socket; "free" means none | `port_holders` in `tools/lib/endpoint.sh` (new; extracted from `record_port_holders`) | `record_port_holders` (group start and end snapshots in `tools/e2e`); `stop_endpoint`'s wait, failure snapshot and error message, in both `tools/e2e` and `tools/dev-app` (new consumers) |
| The endpoint's processes: `ENDPOINT_PID` and its descendants at stop time, excluding the harness's stamper | `stop_endpoint` (walk) and `start_endpoint` (keeps the stamper outside the tree) in `tools/lib/endpoint.sh` | `tools/e2e` `run_group` and its EXIT trap; `tools/dev-app` EXIT trap; the self-test |
| Stop wait limit | `ENDPOINT_STOP_TIMEOUT_MS` in `tools/dev.env` | `stop_endpoint`; the self-test (overridden through the environment) |
| Endpoint port | `ENDPOINT_PORT` in `tools/dev.env` (existing) | `start_endpoint`, `ensure_port_free`, `port_holders`, `forward_endpoint_port`, app dart-defines; the self-test overrides it |
| Something already answers on the port, so the run aborts | `ensure_port_free` (unchanged) | `tools/e2e` group start; `tools/dev-app` start |

## 4. Data / schema shape

None.

## 5. Test strategy

- **The stop frees the port, leaves siblings alone and records the signalled PIDs (AC1, AC2):** the
  outer test is the new self-test in `node --test tools/sweep/` (the sweep's `self-test` layer, run
  on CI's Linux job and locally). It uses a stand-in tree on its own port with the real stamper
  plumbing, and a sibling process in the same group that must survive. It asserts the stamped PID
  line. It is RED against today's stop.
- **A stop that can't free the port fails visibly, and a second stop is a no-op (AC3):** the same
  self-test, with a grandchild that ignores SIGTERM and a short limit. It asserts exit 1 and exactly
  one `error:` naming the holder's PID, and the test's own cleanup kills the stand-in.
- **Real wrangler, all groups (AC1, AC4):** a local `tools/e2e` run, which shows nothing regressed
  (macOS never reproduced the bug), and the one dispatched CI sweep. The fix is proven only by
  `e2e-android` being green with 5 tests and every group-end snapshot reading "nothing holds port
  8787". AC3's "in the E2E run record" relies on the sweep putting stdout and stderr in one log; a
  standalone run shows the `error:` in the terminal.
- **dev-app:** a manual check only, as the spec gives it no test layer. It shares the stop the
  self-test covers.

## 5a. Failure posture

Fail fast and visibly. A stop that misses its limit writes a port snapshot and exits 1 with the
holders named, in the layer log for E2E or on the terminal for dev-app. Irreversibility is guarded
by signalling only the snapshotted tree. PID reuse within one stop's milliseconds is accepted as
negligible. There is no retry and no SIGKILL.

## 6. Definition delta

There is no area doc for tooling, so `docs/definitions/` is unchanged. At sign-off, DECISIONS.md D7's
"port is free after every group" bullet becomes the stop rule:
- the tree is snapshotted, with the stamper kept outside it;
- SIGTERM goes to the snapshot, and the signalled PIDs are recorded;
- the stop waits on LISTEN `port_holders` up to `ENDPOINT_STOP_TIMEOUT_MS`;
- if the port is still held at the limit, it fails visibly.

## 7. First slices

- *A developer runs the self-test layer and sees a stand-in endpoint stopped: its grandchild held
  the port and its middle parent died on SIGTERM, yet the port is free, the sibling process is
  still alive and the signalled PIDs are recorded.* This is surface-less, per the spec's Demo test.
  It is the walking skeleton: snapshot, signal, record, wait. It is RED on today's stop.
- *A developer runs the self-test layer and sees a stand-in that won't exit make the stop fail at
  the limit, with one error naming the holder, while a second stop stays silent.*
- *A developer runs `tools/e2e android` locally and sees all three groups run and every group-end
  snapshot reading "nothing holds port 8787" (no regression). A developer quits `tools/dev-app` and
  sees the signalled-PIDs line and the port free.* Then the one CI sweep proves AC4.

## Slices

- [x] 1. A developer runs the self-test layer and sees a stand-in endpoint stopped: its grandchild held the port and its middle parent died on SIGTERM, yet the port is free, the sibling process is still alive and the signalled PIDs are recorded.
- [x] 2. A developer runs the self-test layer and sees a stand-in that won't exit make the stop fail at the limit, with one error naming the holder, while a second stop stays silent.
- [x] 3. A developer runs `tools/e2e android` locally and sees all three groups run and every group-end snapshot reading "nothing holds port 8787" (no regression); a developer quits `tools/dev-app` and sees the signalled-PIDs line and the port free.
- [x] 4. A developer dispatches the full sweep on CI and sees `e2e-android` green with 5 tests and every group-end snapshot reading "nothing holds port 8787".

## Decisions taken during implement

- `start_endpoint` launches the server through `run_endpoint_server`, which the self-test redefines with its stand-in, so the self-test drives the real start (and its stamper plumbing) as well as the real stop. Alternative: the self-test copies the start's plumbing, which would let the two drift.
- The stamper sits on a fixed fd 3, not a named `{fd}`: macOS ships bash 3.2, which has no named file descriptors.
- The stop's wait runs to a millisecond deadline read through `node` (`now_ms`). Rejected: `date +%s` (whole seconds, too coarse for a short limit); counting 100 ms poll steps (each poll's `lsof` costs real time, so a 5 s limit drifted towards 12 s); `perl` (a tool the harness doesn't otherwise need).

- Self-test assertions identify a port holder by PID, never by command name: lsof shows node as `node-Main` on Linux (found by the CI sweep).

## Resume

All four slices closed (18d556b, 5a3c147, 6f7aff8, 864dba0). CI sweep 40087483205: e2e-android green, 5 tests, every group-end snapshot "nothing holds port 8787"; its one red (the Linux self-test's `node` vs `node-Main` regex) was fixed in 864dba0 and is green on the `fast` run 40088965490. Technical unknown (a) is settled: the Linux wrangler tree was attached at stop time. Implement gate closed: the five implement-time decisions were accepted, and the user's manual dev-app Ctrl-C check passed (signalled PIDs 54090, port 8787 free afterwards). Next: `/finish-feature`.
