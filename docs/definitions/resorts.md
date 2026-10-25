# Resorts: the resort list

The home screen of the app: the ski areas it supports, so a skier can find the one they're visiting.
The list stands alone on its screen.

## What is listed

- One entry per lift-linked ski area, as skiers know it (Paradiski is one entry, not Les Arcs and La
  Plagne). The list is flat and hand-curated; it currently holds **Paradiski**, **Les 3 Vallées** and
  **Espace San Bernardo**.
- Each row shows the resort's name, with its countries on a smaller line below, in English, in
  catalogue order and joined with " · " (for example "France · Italy").
- The app sorts rows by name, ignoring accents and capitals, whatever order the catalogue arrives in.
- Rows don't respond to taps and show no tap affordance.
- Each entry also carries a centre point, which isn't shown.

## Freshness

- A loaded list is saved on the device and survives a relaunch, including with no signal.
- A saved list is shown at once on launch. Every launch also fetches quietly in the background, and
  pulling the list down fetches again.
- With nothing saved, a loading indicator shows while the first fetch runs.
- Any understood response replaces the shown and saved list; there is no version comparison. A
  response to an earlier request never overwrites a later one.
- A catalogue with no entries, or with an entry missing its name, countries or centre point, is not
  understood and replaces nothing.
- Saving is all-or-nothing: a failed save leaves the previous saved list intact, and the new list is
  still shown.
- A saved copy the app can't read (not text, corrupt, or an older or unknown schema) counts as
  nothing saved, and a fetch follows.
- There is no "last updated" indicator.

## When the list can't be refreshed or read

"Update the app" means only that the service sent a document of the wrong kind or an unknown schema
version. Everything else is "couldn't refresh" or "couldn't load": unreachable, timed out, any non-2xx
answer, a body that isn't a valid envelope, and an empty or malformed catalogue.

| Situation | What the skier sees |
|-----------|---------------------|
| A pull fails with a list shown | The list stays; a brief floating message "Couldn't refresh resorts" |
| The quiet launch fetch fails with a saved list | Nothing: the saved list stays |
| Nothing saved and the fetch fails | Full-area "Couldn't load resorts" with a Retry button; pulling down also retries |
| "Update the app" with nothing saved | Full-area message with a Retry button; pulling down also retries |
| "Update the app" with a saved list | The list stays usable, with a notice card above it: "A newer resort list needs an app update. Showing your saved list." It has no dismiss control; a later understood answer clears it and a later failed pull leaves it |

"Update the app" shows whichever fetch found it, launch or pull.

## Look

The app's visual basis, set here for every screen to inherit (light only; dark mode and contrast
standards belong to accessibility work):

- **Glacier teal.** The colour scheme is seeded from teal `#00687A`; the screen title, primary buttons
  and progress indicators use the primary colour.
- **Ground and cards.** The screen sits on a light teal-grey ground. Content items (resort rows) are
  white raised cards with rounded corners and a small gap, so they lift off the ground. State
  messages don't get a card.
- **Notices over content** (the update notice) are a tinted card in the theme's container colour with
  a leading info icon, not amber, so they read as information rather than a warning.
- **Full-area state messages** sit on the ground with a large primary-coloured icon, a heading and the
  action button below.
- **Snackbars float** with an inset, above anything in the bottom bar. The credits line sits in the
  bottom bar.

## Entry points (navigation aid)

- `app/lib/resorts/` — the catalogue and its parse, saved copy, list state and view.
- `app/lib/theme/app_theme.dart` — the theme.
- `app/lib/endpoint/contract_envelope.dart` — `openDocument`, the one reader of served and saved bytes.
- `endpoint/catalogue/curated.json` — the curated list.
