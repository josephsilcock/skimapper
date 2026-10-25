# Backlog

Bugs and suggestions. Delete entries when resolved.
Feature IDs reference [FEATURES.md](FEATURES.md).

**Next free IDs**: `F22`, `B5`, `C11`.
ID prefixes: 
- `F` = feature
- `B` = bug
- `C` = code - non user facing improvement

When you create a new backlog item / spec, take the next free ID and bump this line in the same commit. IDs of completed-and-deleted items stay retired — never reuse them, because spec filenames, commit messages, code comments and audit-event names still reference the original meaning.

---

## Next up

The agreed order for roughly the next five items — a queue, where the rest of this file is a pool.
Re-ranked whenever an item lands (`/finish-feature` pops the head and tops the list back up); an item
below that gets picked up out of turn should say why in its spec.

1. **F5** Resort map
2. **F4** Open a resort from the list
3. **F8** Choose route start and end
4. **F11** Quickest route
5. **F16** Resort data available offline

---

## Features

- **F2** Skiers can sort the resort list from closest to furthest, with the distance to each resort shown. Their location is only used on the device to work out distances and never leaves it. Builds on the resort list (`docs/definitions/resorts.md`), which sorts by name and keeps each resort's centre point for this.
- **F3** Skiers can mark resorts as favourites, and their favourites are remembered between visits to the app. This is the app's first user state, so it is where the drift database starts (migration 1, DECISIONS.md D5). Builds on the resort list; catalogue entries carry no id yet, so this adds one.
- **F4** Opening a resort from the list takes the skier straight to its map, and the app remembers which resort was open, so it reopens there next time. Depends on F5. Once a resort opens its map, the resort list stands alone on its screen, so this also moves or retires the fixture-map proof that sits below the list today (with F5).
- **F5** Each resort is shown on a full-screen map that's easy to read on the mountain: a muted background with shaded terrain, runs drawn in their difficulty colours and labelled with their names, and lifts drawn and labelled so they stand apart from the runs, with drag lifts marked differently from aerial lifts. The map frames the whole resort when it opens. The fixture-map proof (map, map line and attribution) pinned below the resort list today is a temporary arrangement: this moves it onto the resort's map screen or retires it, so the list is alone on its screen. Also confirms the OpenSkiMap licence (DECISIONS.md D2) before OpenSkiMap data ships, unless F20 does first.
- **F6** The map shows which lifts and runs are open right now. Lifts and runs known to be closed fade back, the resort's name bar says how up to date the information is, and information that has become too old to trust is no longer shown rather than misleading the skier. Depends on F5.
- **F7** Tapping a lift shows its name, its type and whether it's running, along with any message the resort has given about it, such as when it's due to open. Depends on F5.
- **F8** Skiers can plan a route between two points in the resort by choosing a start and an end, either by tapping the map or by picking which point they're setting and then tapping where they want it. The chosen points are marked on the map.
- **F9** Skiers can set a route's start or end by searching for a run or lift by name, ignoring accents and capitals, or by using their current location to start from wherever they are. Depends on F8.
- **F10** Skiers can swap the start and end of a route to plan the way back, or clear both to start again. Depends on F8.
- **F11** The app finds the quickest route and shows it on the map and as a list of steps, each naming the run or lift and its kind. It gives the total time, and how much of it is spent skiing and how much on lifts, and the map moves to show the whole route. Depends on F8.
- **F12** Skiers can avoid runs of any difficulty they aren't comfortable with (blue, red, black or off-piste), and routes only use the runs they allow. Depends on F11.
- **F13** Skiers can choose to prefer skiing over riding lifts, for routes that spend more time on the snow even if they take a little longer. Depends on F11.
- **F14** Skiers can choose to avoid lifts and runs that aren't open. The route then goes around them, and the app says when it has done so and how much longer the detour takes. Out of season, when everything is closed, routes can still be planned ahead. Depends on F6 and F11.
- **F15** When there's no route, the app explains why and what to change: the points aren't connected, the route needs harder runs than the skier allows (and which difficulty), it can only be reached on a lift or run that isn't open, or the start and end are the same place. Depends on F11 and F12.
- **F16** Once a resort has been opened, its runs, lifts and routes are kept on the device, so the map and route planning keep working with no signal on the mountain.
- **F17** The background map and terrain shading for each opened resort are also saved for use without a signal, with progress shown while they save and a message if saving fails. Depends on F16.
- **F18** Skiers can see which resorts are saved on their device and how much space each one uses, and remove any they no longer need. Depends on F16 and F17.
- **F19** The app keeps resort information up to date without slowing skiers down: it checks for changes at most twice a day, and when a resort's map or routes change, it updates the copies saved on the device. Depends on F16 and F20.
- **F20** Resort maps, routes and live status stay current without the app needing an update: resort information is refreshed every day, new resorts can be added and sources fixed behind the scenes, and a problem with one resort's information doesn't stop the others refreshing.
- **F21** The app follows the device's light or dark setting, with a consistent look throughout and text that meets accessibility contrast standards.

---

## Bugs

- **B4** The unreachable-endpoint E2E (now the first-launch test in `endpoint_scripted`, formerly `endpoint_stopped`) passed on CI by coincidence before B2's fix: its "unreachable" line appeared because the first fetch hit the same first-launch UI freeze, not because a closed port was refused. Its pass is now real, but CI's first launch still has thin headroom (app-side fetch measured 4.4-8.0 s, endpoint-side 0.6-2.4 s, on the first launch after each install); watch for a recurrence. A second symptom of the same cold-start stall: on a freshly booted emulator `catalogue_serving` on Android once aborted with "Expected 3 tests, received 2" (the app's event loop 14-25 s late, and `resort_list_test` never requested by the native side); a rerun on the warm emulator is the check. **Recurred 2026-10-24** on main's sweep (run 40105890900, iOS), before F1 retired the group: `endpoint_malformed`'s first fetch logged `event loop late by 4889 ms` then `unreachable (timeout after 3000 ms) in 4514 ms` against a ready endpoint. To be fixed later.

---

## Code

- **C1** The service behind the app is protected from abuse: heavy or automated use is limited, AI scrapers are refused, and resort data can only be reached through the service.
- **C2** The service can tell requests from genuine installs of the app apart from others, so it can refuse anything that isn't the real app.
- **C3** Failures in the service and its daily refresh are noticed and reported, with enough detail to find and fix the cause quickly. Depends on F20.
- **C6** Skeleton hardening: a missing `ENDPOINT_URL`/`ENDPOINT_TIMEOUT_MS` define shows a loading or misleading "could not be reached" state instead of a clear failure.
- **C8** A test status site: the one place anyone, technical or not, goes to see the state of the automated tests: what they check, whether they're passing, and how that is changing. The aim is a site that is genuinely useful to browse, not a fixed checklist; the spec should shape it around that. The driving use case is a non-technical stakeholder working out what still needs testing by hand. Today the only view is the per-layer summary table `tools/sweep/report.ts` writes to a GitHub Actions step summary, with the raw results buried in the uploaded artefacts: developer-facing, and inside GitHub. Whatever form it takes, it includes at least the following.
  - **Where**: its own hosted microsite, linkable and readable without a GitHub account or any knowledge of GitHub Actions. Published from trunk's latest full sweep, so it always describes what is merged.
  - **What it shows**: tested behaviour in plain language (no test file names or code identifiers up front), grouped by product area (`docs/definitions/`) and feature (`docs/FEATURES.md`). For each behaviour: which platforms check it (iOS, Android, or neither for a check that never touches the device), whether it passed on the latest run, and when that run happened.
  - **What it doesn't cover**: the most useful part for planning manual testing. Shows each area's behaviours that have no automated test, plus the kinds of checking automation does not do at all (for example look and feel, real devices, real GPS on the mountain).
  - **History**: past runs stay viewable, each saying which version of trunk it tested and when. A stakeholder can see when a behaviour started being tested, when it last failed, and which tests sometimes pass and sometimes fail (flaky) and so are less trustworthy.
  - **Test coverage**: some measure of how much of the app and endpoint the tests exercise, and how that changes over the run history. Deliberately open-ended: the spec decides what it means here, from code coverage (the share of lines or branches run by tests, per area) to coverage of the spec'd behaviours, and how to present it so a stakeholder doesn't read a high percentage as "nothing to test by hand".
  - **Drill-down**: a developer can still open any test across all layers (fast and full sweep, all platforms) for its pass/fail, duration and failure output, filterable. This is a secondary view; the stakeholder view comes first.
  - **Open questions for the spec**: where the plain-language wording comes from (test names, Gherkin acceptance criteria, or an annotation on each test) and how it is kept from drifting; how "not covered" is worked out (acceptance criteria with no linked test is the obvious source); hosting (Cloudflare, alongside `endpoint/`, is the natural fit) and whether it needs access control; where run history is stored and how long it is kept (GitHub's uploaded artefacts expire, so they can't be the record).
  - Builds on C5's sweep reporting (`.github/workflows/push.yml`, `sweep.yml`).
- **C9** The sweep and CI report reject arguments they don't recognise: today `tools/full-sweep --layer app` or `--layers=app` is silently ignored and runs every layer, E2E included (about 90 minutes), because `layersFromArgs` (`tools/sweep/layers.ts`) only looks for the exact switch. Each entry point should accept only its own switch and value (plus `report.ts`'s results dir) and fail with one `error:` line. Build on `layersFromArgs` and the `tools/sweep/cli.ts` boundary.
- **C10** The service is deployed for real: a Cloudflare account, the private R2 bucket and a deploy workflow, so the app works on a phone outside development, with D1's free-tier limits checked against the first deploy.
