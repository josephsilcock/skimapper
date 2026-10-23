# B1 Map removed before it is ready throws

## Intent

Removing the map while it is still starting up throws (`LateInitializationError` from the map
plugin's dispose, because its platform channel is only assigned once the native view exists). On
CI's slow devices every E2E test that tears the app down early hits it, so the Android E2E is red
on every main sweep and the iOS E2E fails `endpoint_unreachable_test` in teardown. The goal: the map
can be removed at any moment during start-up without an error, so the sweep reports real failures
only.

**Picked up out of turn** (the Next up queue has F1 at its head): it keeps both E2E layers red on
CI, so every main sweep is red and a new regression would be invisible against it.

## Demo test

Surface-less in the product sense: the app has one placeholder screen and no navigation yet, so no
skier can leave the map today. The sentence is therefore: *"A developer dispatches the branch sweep
and sees no teardown failure from map disposal on Android or iOS, and a local test that removes the
map before its native view exists passes on every run."* Justified rather than assumed: the defect
is a teardown race with no user-visible screen of its own, and the observable state that changes is
the error no longer being raised.

## Acceptance criteria

```gherkin
Scenario: The map is removed before its native view exists
  Given the map widget is on screen
  And its native view has not been created yet
  When the map is removed
  Then no error is raised

Scenario: The map is removed while the fixture check is still running
  Given the map has been created and is still checking whether the fixture feature rendered
  When the map is removed
  Then no error is raised
  And the fixture check stops and reports nothing once the map is removed

Scenario: The fixed behaviour is proven on CI
  Given the fix is on its branch
  When the full sweep is run once on that branch from Run workflow
  Then the per-layer results show no teardown failure from map disposal in the Android E2E layer
  And the per-layer results show no teardown failure from map disposal in the iOS E2E layer
```

- ACs 1 and 2 must be reproducible **deterministically and locally**: a widget test with a fake map
  platform, or a device test, as design chooses. "Passes locally" on a device is what hid this bug.
  The AC 1 test must fail against today's code.
- The ACs sample the two windows where a fault is possible. The third window (the map is created but
  its style has not loaded yet) is already handled by the plugin, which disposes its controller and
  skips the rest of start-up once the widget is gone.
- AC 3 is judged on map-disposal teardown failures only, not the layer verdict: B2 or an unrelated
  flake may still turn a layer red. One dispatched sweep is the bar.

## Constraints

- The fix stops the error at its cause. It must not catch or filter errors by type or app-wide
  (for example catching `LateInitializationError`, or filtering `FlutterError.onError` or
  `PlatformDispatcher.onError`). Any other error from map disposal must still surface.

## Non-goals

- **B2** (`endpoint_not_understood_test` timing out on CI's iOS simulator). It stays a separate
  backlog item, and the iOS E2E layer may still be red because of it when B1 closes.
- **No upstream issue or PR** to `maplibre_gl`. The fix lives in this repo only.
- **No change to the E2E tests' assertions or timeouts** to make them pass. The new
  removal-during-start-up test(s) are additions.
- **No other map behaviour changes** (style, camera, fixture check result, placeholder layout).
- No general hardening of other plugin lifecycle races beyond removal during start-up.

## NFR trigger

None. No performance, security, data-volume or migration implication. Concurrency is the bug itself
(a dispose racing native view creation), and it is covered by the ACs.

## Simplification levers

The cost driver was a deterministic reproduction on a device, which would need a way to hold native
start-up. It is relaxed to allow a widget test with a fake map platform, which reproduces the window
cheaply in the fast layer. Dropping local proof altogether (CI sweep only) was rejected: a
regression would again surface only on CI.

## UX note

No user-visible change.
