# F1 Resort list

## Intent

A skier opening the app should find the resort they're visiting. Today the app opens on a placeholder
screen. F1 makes the list of supported ski areas the home screen, each shown with its name and
countries. The skier can pull down to refresh it, and the list stays usable without a signal once it
has been loaded, including after the app is relaunched. It is the entry point every later feature
hangs off: distance sort (F2), favourites (F3) and opening a resort's map (F4).

## Scope rules

- **One entry per lift-linked ski area, as skiers know it.** Paradiski is one entry, not Les Arcs
  and La Plagne. Later routing spans the whole connected area.
- **The supported list is hand-curated in the repo** (name, countries, centre point) and published
  as the catalogue document. The centre point is carried for F2 and is not shown. The first list is
  **Paradiski**, **Les 3 Vallées** and **Espace San Bernardo** (La Rosière, France, and La Thuile,
  Italy). F20 later generates the catalogue.
- **Countries are English country names, shown in catalogue order**, all of them joined in one line,
  for example "France · Italy".
- **The list is flat, and the app sorts it by name, ignoring accents and capitals.** It never relies
  on catalogue order, which F20 will regenerate.
- **The resort list replaces the placeholder as the home screen.** The skeleton message line, and
  the endpoint route and document behind it, are retired. The offline fixture-map proof and the
  attribution line stay on the home screen until F5 replaces them.
- **Freshness:**
  - Once a list has been loaded, it is saved on the device and survives a relaunch.
  - A saved list is shown at once on launch.
  - Every launch also fetches quietly in the background. Pulling down fetches again.
  - With nothing saved, a loading indicator shows while the first fetch runs.
  - There is no "last updated" indicator.
- **Replace rules:**
  - Any understood response replaces the shown and saved list. There is no version comparison.
  - A response to an earlier request never overwrites a later one, for example a slow launch fetch
    landing after a pull.
  - A catalogue with no entries, or with any malformed entry (missing a name, countries or centre
    point), counts as not understood and replaces nothing.
  - Saving is all-or-nothing: a failed save leaves the previous saved list intact.
  - A saved copy the app can't read (corrupt, or an older schema) counts as nothing saved, and a
    fetch follows.
  - How the list is stored is a design choice: a saved envelope file or drift (D5).
- **Failure classification:**
  - **"Update the app"** covers only an envelope of the wrong kind or an unknown schema version.
  - **"Couldn't refresh" and "couldn't load"** cover everything else: unreachable, timed out, any
    non-2xx response, a body that isn't a valid envelope, and an empty or malformed catalogue.
  - D8's mapping (where non-2xx is "not understood") is amended at sign-off.
- **Failure states:**
  - **A pull fails with a list shown:** the list stays, with a brief non-blocking "couldn't
    refresh" message.
  - **The quiet launch fetch fails with a saved list shown:** nothing is shown. The saved list just
    stays.
  - **Nothing saved and the fetch fails:** a full-screen "couldn't load resorts" message,
    recoverable by pulling down or by a retry control.
  - **"Update the app" with nothing saved:** a full-screen message, with retry and pull still
    available.
  - **"Update the app" with a saved list:** the list stays shown and usable, with the message shown
    over it, and pull still works.
  - "Update the app" shows whichever fetch found it, launch or pull.
- **Rows don't respond to taps and show no tap affordance** until F4.
- **The shared TypeScript envelope builder is extracted** (from C6): the catalogue is the second
  document kind, and the builder is duplicated today in `endpoint/scripts/seed-local.ts` and
  `endpoint/test/integration/artefacts.test.ts`.

## Demo test

*A skier opens the app and sees the three supported ski areas listed by name, each with its
countries. With the endpoint stopped and the app relaunched, they still see the same list.*

## Acceptance criteria

Test levels:
- The offline-relaunch scenario is verified end to end with the app process restarted, so a
  memory-only cache cannot pass it.
- The pull-to-refresh scenario is verified end to end with the catalogue changed mid-session.
- The E2E harness therefore needs to relaunch the app and reseed the endpoint within a test. That
  cost is accepted.
- The remaining scenarios may be proven at whatever level design chooses.

```gherkin
Feature: Resort list

  Scenario: Browse the supported ski areas
    Given the catalogue lists Paradiski, Les 3 Vallées and Espace San Bernardo
    When the skier opens the app
    Then they see the three ski areas sorted by name
    And each row shows its name and every one of its countries
    And Espace San Bernardo shows "France · Italy"

  Scenario: The app sorts by name, ignoring accents and capitals
    Given the catalogue lists "Zermatt", "Évolène" and "alpe", in that order
    When the skier opens the app
    Then they see "alpe", "Évolène", "Zermatt" in that order

  Scenario: Pull down to refresh
    Given the skier is looking at the resort list
    And the catalogue has since gained a ski area
    When they pull the list down
    Then the new ski area appears in its sorted place

  Scenario: The list works without a signal once loaded
    Given the skier has loaded the resort list once
    And the app process has been restarted
    And the service cannot be reached
    When they open the app
    Then they see the saved list straight away
    And no refresh-failure message is shown

  Scenario: A pull fails while a list is shown
    Given the skier is looking at a saved resort list
    And the service cannot be reached
    When they pull the list down
    Then the list stays as it was
    And a brief message says it couldn't refresh

  Scenario: A server error is a failed refresh, not an update prompt
    Given the skier is looking at a saved resort list
    And the service answers with a server error
    When they pull the list down
    Then the list stays as it was
    And a brief message says it couldn't refresh

  Scenario: An empty catalogue replaces nothing
    Given the skier is looking at a saved resort list
    And the service returns a catalogue with no entries
    When they pull the list down
    Then the list stays as it was
    And a brief message says it couldn't refresh

  Scenario: First launch with no signal
    Given nothing has been saved on the device
    And the service cannot be reached
    When the skier opens the app
    Then they see a message that the resorts couldn't be loaded
    And pulling down or retrying loads the list once the service can be reached

  Scenario: Unknown version with nothing saved
    Given nothing has been saved on the device
    And the service returns a catalogue version this app doesn't know
    When the skier opens the app
    Then they see a full-screen message asking them to update the app
    And retry and pull down are still available

  Scenario: Unknown version with a saved list
    Given the skier has a saved resort list
    And the service returns a catalogue version this app doesn't know
    When the skier opens the app
    Then they see the saved list
    And a message over it asks them to update the app
```

## Non-goals

- **Search or filtering by name.** The curated list is short.
- **Sorting by distance, or using location at all** (F2).
- **Favourites** (F3).
- **Opening a resort or navigating anywhere from a row** (F4). Rows aren't tappable.
- **Any per-resort data:** maps, runs, lifts, manifests or saved resort directories (F5, F16).
- **Generating the catalogue from OpenSkiMap or any daily refresh** (F20). The list is curated by
  hand.
- **Confirming the OpenSkiMap licence.** It moves to the first feature that takes in OpenSkiMap data
  (F5 or F20); D2 is updated to say so at sign-off.
- **A real deploy** (Cloudflare account, R2 bucket, deploy workflow): this is C8. F1 runs against
  the local endpoint in dev and E2E.
- **A "last updated" indicator, or showing that data is stale.**
- **Light and dark theming, or accessibility contrast work** (F21).
- **Retiring the fixture-map proof** (F5 does that).

## NFR trigger

This is the app's **first on-device persistent storage**. Whatever it stores must handle an
unreadable or older saved copy (covered by the replace rules), and any storage schema it introduces
is the one F3 and F16 migrate from. Data volume is trivial (a handful of entries), and there are no
performance, security or concurrency implications beyond the request ordering rule above. The
catalogue holds no personal data.

## Simplification levers

- **Storage mechanism:** persisting the list is the main new cost. Saving the catalogue envelope as
  a file and reopening it through the single version check avoids committing a database schema
  before there is real user state. Design weighs this against drift.
- **In-memory only:** not recommended. It drops persistence across relaunches and gives up the case
  that matters on the mountain.
- **One generic error state:** not recommended. It loses the difference between "no signal" and
  "update the app" for a small saving.

## UX note

- **Home screen:**
  - A title, then the list.
  - Each row: the name on the first line, the countries on a smaller second line.
  - Pull-to-refresh on the list.
  - The fixture-map proof and the attribution line stay below the list until F5.
- **First launch with nothing saved:** a loading indicator in the list area while the fetch runs.
- **A pull fails with a list shown:** a transient snackbar-style message. A failed launch fetch
  shows nothing.
- **No list and the fetch fails:** the message and a retry control fill the list area.
- **"Update the app":**
  - Full-screen in the list area when nothing is saved.
  - Over the saved list, which stays usable, when one exists.
