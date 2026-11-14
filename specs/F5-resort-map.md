# F5 Resort map

## Intent

A skier who picks a resort today sees nothing of it: rows don't respond, and the only map is a
fixture proof pinned under the list. F5 gives each curated resort a full-screen map that is easy to
read on the mountain: a muted background with shaded terrain, runs in their difficulty colours with
their names, and lifts that stand apart from the runs, with drag lifts distinct from aerial lifts.
Tapping a resort in the list opens its map, framed on the whole resort. Every later feature
(status, lift details, route planning, offline use) draws on this map.

It is also the first feature with real resort data on the device. Until the daily refresh (F20)
exists, a developer-run build cuts each curated resort's data and publishes it to the endpoint, in
the per-resort manifest-and-parts shape the architecture already sets out.

**Demo sentence:** *A skier taps "Paradiski" in the resort list, and sees a full-screen map of the
whole of Paradiski, with its runs in their difficulty colours and named, and its lifts drawn and
named apart from the runs.*

## Acceptance criteria

```gherkin
Scenario: Opening a resort shows its map, framed on the whole resort
  Given the resort list shows "Paradiski"
  When the skier taps "Paradiski"
  Then a full-screen map of Paradiski opens, with a name bar reading "Paradiski"
  And the map is framed so every run and lift of the resort is in view
  And only operating runs and lifts are drawn: proposed, planned, under construction, disused and abandoned ones are not

Scenario: Runs are drawn in their difficulty colours and labelled
  Given a resort's map is open
  Then each downhill run is drawn green (novice), blue (easy), red (intermediate) or black (advanced, expert)
  And freeride and extreme runs are drawn as a dashed dark line, and runs with no difficulty in grey
  And run areas are drawn as a faint fill in their difficulty colour
  And named runs are labelled with their names, and labels that would overlap may be hidden until zoomed in
  And nordic, ski-touring and sledging runs are not drawn

Scenario: Zooming in on a named run or lift shows its label
  Given a resort's map is open
  When the skier zooms in on a named run or lift
  Then its name is shown

Scenario: Lifts stand apart from runs, drag lifts from aerial lifts
  Given a resort's map is open
  Then each lift is drawn in a lift style unlike any run, and named lifts are labelled with their names (overlapping labels may be hidden until zoomed in)
  And drag lifts (T-bar, J-bar, platter, rope tow, magic carpet) are drawn differently from aerial lifts
  And chairlifts, gondolas, cable cars, mixed lifts, funiculars and other rail lifts, lifts with no type and lifts of any other type use the aerial style

Scenario: The background is muted with shaded terrain, and credited
  Given a resort's map is open
  Then the background map is muted and shaded with the terrain
  And the map screen shows the credits for the sources the map's data came from: "© OpenStreetMap contributors · OpenSkiMap · Protomaps · Mapterhorn" when it comes from those

Scenario: Going back returns to the list, which stands alone
  Given a resort's map is open
  When the skier goes back
  Then the resort list is shown alone on its screen, with no map and no credits line

Scenario: The map can't be loaded
  Given the resort's map data can't be fetched (no signal, unreachable, timed out, not understood)
  When the skier opens the resort
  Then a full-area "Couldn't load map" message with a Retry button is shown
  And Retry fetches again

Scenario: A part that is incomplete or doesn't match the manifest isn't shown
  Given a fetched part is incomplete or doesn't match its hash in the resort's manifest
  When the skier opens the resort
  Then a full-area "Couldn't load map" message with a Retry button is shown

Scenario: The map data needs a newer app
  Given the endpoint answers the resort's map data with a wrong kind or an unknown schema version
  When the skier opens the resort
  Then a full-area "update the app" message with a Retry button is shown
```

## Rules

- **Entry and exit.** Every row in the resort list opens that resort's map. The map screen has a
  name bar showing the resort's name and a back control to the list.
- **Data per open.** The resort's data is fetched every time its map opens. A loading state shows
  while the fetch runs. Parts are written to a scratch location for the current open only. Nothing
  is kept between opens or launches.
- **Only the latest answer counts.** A map screen shows only the answer to its own most recent
  fetch for its own resort: going back and opening another resort, or pressing Retry twice, never
  shows a stale or wrong map.
- **Resorts.** All three curated resorts get map data. Any resort whose data can't be fetched shows
  the same "Couldn't load map" state.
- **Interaction.** Pan, zoom and rotate, with a compass that resets to north. No tilt and no 3D
  terrain. Tapping a run or lift does nothing.
- **Fixture proof retired.** The fixture map and its "map:" line go. The resort map takes over as
  the proof that a map renders from a local file, including its E2E check. The credits line moves
  from the list screen to the map screen.
- **Data source.** Runs and lifts come from OpenSkiMap's exports, the background map from
  Protomaps and the terrain from Mapterhorn, cut per resort by a build a developer runs by hand and
  published to the endpoint as a manifest and parts. Which runs and lifts belong to each resort
  (and so what "the whole resort" frames) is a curated mapping the build owns, whatever the source.
- **Test data.** Widget and E2E tests (CI included) use a small committed fixture resort, a
  manifest and tiny parts published through the same endpoint path. The real hand-run build is for
  development and the demo pack only; its output is not committed.

## Assumptions

- **OpenSkiMap licence (D2).** `/design-feature` confirms it first. If it can't be confirmed,
  runs and lifts come from D2's fallback (raw OSM from a Geofabrik extract, grouped by
  `landuse=winter_sports`). The behaviour above doesn't change either way, except that the credits
  name only the sources actually used. The same first design step checks the Protomaps and
  Mapterhorn attribution terms.
- The service isn't deployed yet (C10), so the map works against the local endpoint, the same as
  the resort list.

## Non-goals

- **Remembering the open resort** or reopening it on launch: F4, which shrinks to that.
- **Keeping any resort data on the device**, or a map that works with no signal: F16 and F17.
- **A daily or automated refresh**, adding resorts, or scheduled publishing: F20. F5's build is
  run by hand.
- **Open or closed status**, fading closed lifts and runs, or data age in the name bar: F6.
- **Tapping a lift or run** for details: F7.
- **Route start and end, routes, search**: F8-F15.
- **The skier's location** on the map, or sorting by distance: F2 and F9.
- **Tilt or 3D terrain**, satellite imagery, or a choice of map styles.
- **Nordic, ski-touring and sledging runs**, and other winter-sports features (huts, parking,
  restaurants).
- **Dark mode** and contrast standards: F21. The map is light only.
- **Deployment** to real infrastructure: C10.

## NFR trigger

- **Data volume:** each open downloads the resort's parts (expected 5-25 MB, D4) with no caching.
  This is acceptable against the local endpoint only. F16 removes the repeat download.
- **Licence:** OpenSkiMap licence confirmation is a ship blocker (D2), handled as the first design
  step.
- **Performance:** the demo pack shows pan and zoom across Les 3 Vallées, the largest area, staying
  smooth on the test simulator and emulator. The fetch timeout must suit downloads of several MB
  (design). Nothing else (no security, concurrency or migration implications).

## Simplification levers

- **The build is the cost driver:** cutting three areas from three sources and publishing manifest
  and parts. Limiting F5 to one resort (Paradiski) would halve the checking and fixtures, at the
  cost of the other two rows opening to an error until F20. Considered at grilling and rejected:
  all three are in scope.
- **Fetching every open** instead of caching is itself a simplification. It defers all storage to
  F16, at the cost of a repeat download and no offline map.
- Bundling one resort's data in the app instead of serving it was rejected at grilling. It's
  cheaper, but it goes around the manifest/endpoint design and would be thrown away.
- Reading the basemap and terrain over HTTP by byte range (`pmtiles://http…`) instead of
  downloading them was rejected at the gate. It breaks the "no map style references a remote URL"
  principle and the local-file path F16 builds on.
- "Muted" and "shaded" are pinned to concrete style properties at design (for example a hillshade
  layer present, a desaturated basemap).

## UX note

- The list's rows become tappable, with a tap affordance.
- The map screen is full-screen under a name bar (resort name, back control), with the credits line
  at the bottom.
- The loading, "Couldn't load map" and "update the app" states follow the list's full-area state
  style (definitions/resorts.md § Look).
- On a colourless, muted background the runs' colours and the lifts' dark style carry the meaning.
