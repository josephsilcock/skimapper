# Resort map: a resort's full-screen map

What a skier sees after tapping a resort in the list: a full-screen map of the whole resort, easy to
read on the mountain. Resort data is light only; dark mode belongs to accessibility work.

## Opening and leaving

- Every row in the resort list opens that resort's map under a name bar: the resort's name in the
  primary colour and a back control. The bar shows in every state below.
- The map opens framed so every run and lift of the resort is in view.
- Back returns to the resort list, which stands alone on its screen: no map, no credits line.

## What is drawn

- **Which runs and lifts.** Only operating runs and lifts, and only downhill runs. Proposed, planned,
  under construction, disused and abandoned ones, and nordic, ski-touring and sledging runs, are not
  drawn.
- **Runs** are lines in their difficulty colour: green (novice), blue (easy), red (intermediate),
  black (advanced, expert). Freeride and extreme runs are a dashed dark line; runs with any other
  difficulty, or none, are grey. A run area is a faint fill in its difficulty colour.
- **Lifts** are a dark core inside a white casing, which no run has. Drag lifts (drag lift, T-bar,
  J-bar, platter, rope tow, magic carpet) are dotted; every other type, or none, is solid, with a
  dot at each station from zoom 14 (below that the dots crowd the map).
- **Labels.** Named runs and lifts are labelled with their names, and labels that would overlap may
  be hidden until zoomed in. Town, village and peak names are kept, in grey.
- **Background.** Muted greys with no points of interest or icons, shaded by terrain, so the runs'
  colours and the lifts' dark style carry the meaning. The basemap and shading reach a margin beyond
  the framed resort on every side.

## Interaction

- Pan, zoom and rotate; no tilt and no 3D terrain. A compass shows only while the map is rotated and
  resets it to north. Tapping a run or lift does nothing. MapLibre's own logo and attribution button
  are not shown.

## Credits

- The credits for the sources the resort's data came from sit in a bar below the map, shown only
  with a map and never in a loading or failure state. They come with the resort's data; for the
  current resorts: "© OpenStreetMap contributors · OpenSkiMap · Skimap.org · Protomaps ·
  Mapterhorn".

## Loading and failure

"Update the app" means only that the endpoint sent a resort's data in a form a newer app reads.
Everything else is "couldn't load": unreachable, timed out, a non-2xx answer, data not understood
(including a manifest that doesn't pin a basemap, terrain and pistes part), a part that is
incomplete, too long or doesn't match its hash, and a failure to install the map's fonts or layers
or to write the data to the device.

| Situation | What the skier sees |
|-----------|---------------------|
| Fetching | A loading indicator under the name bar |
| Any "couldn't load" | Full-area "Couldn't load map" with a Retry button; Retry fetches everything again, including the map's fonts and layers |
| "Update the app" | Full-area "Update SkiMapper to see this map" with a Retry button |

## Data per open

- The resort's data is fetched every time its map opens, and each part is used only once its size and
  hash match what the resort's manifest says.
- Parts are written to a scratch folder for that open only. Nothing is kept: folders of opens whose
  screens have gone are deleted at the next open, and all are cleared at app launch.
- Only the answer to a screen's own most recent fetch is shown: going back and opening another
  resort, or Retry, never shows a stale or wrong map.
- A MapLibre failure to read a part whose hash matches draws nothing and is not reported.

## Entry points (navigation aid)

- `app/lib/map/` — the open state (`resort_map_open.dart`), screen, map widget, style builder (the one
  table of run and lift looks), manifest parse and scratch folders.
- `app/lib/attribution/attribution_line.dart` — the credits bar.
- `app/lib/endpoint/endpoint_client.dart` — document and part fetches and their verification.
- `endpoint/scripts/build/` — the developer-run build that selects, cuts and bundles a resort's data;
  `endpoint/catalogue/resort-areas.json` names each resort's ski areas.
- `endpoint/fixtures/resort-bundle/` — the committed fixture resort the tests use.
