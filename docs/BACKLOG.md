# Backlog

Bugs and suggestions. Delete entries when resolved.
Feature IDs reference [FEATURES.md](FEATURES.md).

**Next free IDs**: `F22`, `B5`, `C8`.
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

1. **F1** Resort list
2. **F5** Resort map
3. **F8** Choose route start and end
4. **F11** Quickest route
5. **F16** Resort data available offline

---

## Features

- **F1** Skiers can browse the ski areas the app supports, each shown with its name and country, so they can find the resort they're visiting. The list can be refreshed by pulling down, and it stays available without a signal once it has been loaded.
- **F2** Skiers can sort the resort list from closest to furthest, with the distance to each resort shown. Their location is only used on the device to work out distances and never leaves it. Depends on F1.
- **F3** Skiers can mark resorts as favourites, and their favourites are remembered between visits to the app. Depends on F1.
- **F4** Opening a resort from the list takes the skier straight to its map, and the app remembers which resort was open, so it reopens there next time. Depends on F1 and F5.
- **F5** Each resort is shown on a full-screen map that's easy to read on the mountain: a muted background with shaded terrain, runs drawn in their difficulty colours and labelled with their names, and lifts drawn and labelled so they stand apart from the runs, with drag lifts marked differently from aerial lifts. The map frames the whole resort when it opens.
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

- **B4** `endpoint_stopped` passed on CI by coincidence before B2's fix: its "unreachable" line appeared because the first fetch hit the same first-launch UI freeze, not because a closed port was refused. Its pass is now real, but CI's first launch still has thin headroom (app-side fetch measured 4.4-8.0 s, endpoint-side 0.6-2.4 s, on the first launch after each install); watch for a recurrence.
- **B3** On CI, the Android E2E runs only its first group. After `endpoint_serving`, `tools/e2e` aborts with `something is already listening on http://127.0.0.1:8787` before `endpoint_stopped`, so `endpoint_stopped` and `endpoint_malformed` never run. Likely cause: `stop_endpoint` in `tools/lib/endpoint.sh` kills only the endpoint process's direct children (`pkill -P`), so a wrangler/workerd grandchild keeps the port on CI's Linux runner. Locally all three groups run. Found by B1's branch sweep (run 40007409887). It only showed up there because, before B1 was fixed, the first group always failed first.

---

## Code

- **C1** The service behind the app is protected from abuse: heavy or automated use is limited, AI scrapers are refused, and resort data can only be reached through the service.
- **C2** The service can tell requests from genuine installs of the app apart from others, so it can refuse anything that isn't the real app.
- **C3** Failures in the service and its daily refresh are noticed and reported, with enough detail to find and fix the cause quickly. Depends on F20.
- **C6** Skeleton hardening: the skeleton message line shows the text "null" when a valid envelope has no `message` field, and a missing `ENDPOINT_URL`/`ENDPOINT_TIMEOUT_MS` define (or a `FutureBuilder` error) shows "endpoint: loading" or a misleading "could not be reached" instead of a clear failure. Also extract a shared TypeScript envelope builder (currently duplicated in `endpoint/scripts/seed-local.ts` and `endpoint/test/integration/artefacts.test.ts`) when the second document kind lands.
- **C7** CI tooling nits from C5's review: `listSwitch` (`tools/sweep/layers.ts`) throws a bare TypeError when `--layers` is last; `report.ts` relies on `GITHUB_STEP_SUMMARY!`, so a local run throws after printing the table; `toolchain.test.ts` covers only the failing cases of `require_given_jdk` (add a passing case); nothing checks that the `linux`/`android`/`ios` jobs' `--layers` together cover `sweepLayers`.
