# F4 Reopen the last resort

## Intent

A skier visiting one resort shouldn't have to find it in the list every time they open the app. Once
a skier picks a resort, it becomes their **default resort**. Every launch opens straight onto its map
until they pick a different one. Changing resort is always the skier's explicit choice: going back to
the list doesn't change it.

Demo sentence: *a skier opens Paradiski's map, closes the app, launches it again and sees Paradiski's
map straight away, with the resort list behind Back.*

## Acceptance criteria

```gherkin
Scenario: The default resort reopens on launch
  Given the skier opened Paradiski's map from the resort list
  When the app is closed and launched again
  Then Paradiski's map opens straight away, without the resort list showing first

Scenario: Back from the reopened map goes to the list, and the default stays
  Given the app launched onto the default resort Paradiski's map
  When the skier goes back
  Then the resort list shows
  And when the app is closed and launched again, Paradiski's map opens

Scenario: Picking another resort replaces the default
  Given Paradiski is the default resort
  When the skier opens Les 3 Vallées' map from the list
  And the app is closed and launched again
  Then Les 3 Vallées' map opens

Scenario: No default resort
  Given the skier has never opened a resort's map
  When the app launches
  Then the resort list shows, as today

Scenario: The default resort isn't in the saved resort list
  Given Paradiski is the default resort
  And the saved resort list no longer contains Paradiski
  When the app launches
  Then the resort list shows, with no message
  And Paradiski stays the default resort, so it reopens on a later launch once it is back in the saved list

Scenario: No saved resort list can be read
  Given Paradiski is the default resort
  And the saved resort list is missing or can't be read (corrupt, older or unknown schema)
  When the app launches
  Then the resort list behaves as it does today with nothing saved
  And Paradiski stays the default resort

Scenario: The default resort's map can't load at launch
  Given Paradiski is the default resort
  And the endpoint can't be reached
  When the app launches
  Then Paradiski's map screen shows "Couldn't load map" with Retry
  And Back goes to the resort list
  And Paradiski stays the default resort
```

Rules these rest on:

- **Choosing** a resort means opening its map from the list, whether or not the map then loads.
  Reopening the default on launch is not a new choice. Launch never clears or changes the default.
- **The launch decision reads only what is on the device**: the default resort and the saved
  resort list read at launch. It never waits on the network. The default reopens only if it's in that
  saved list; otherwise the list shows.
- The reopened map behaves exactly like one opened from the list. Its name comes from the saved
  list read at launch, and a background fetch that lands later doesn't change a map that is already
  open.
- While launch decides, the skier sees whatever shows before the app's first screen today. There is
  no time budget for this; it's accepted unmeasured at this scale.
- **If storing the choice fails**, the map still opens and the failure is reported in the debug run
  record, as F1 does for a failed list save. No message is shown, and the previous default stays.
- "Launch" means a cold start: after the skier or the OS closed the app, or after a restart.
  Resuming from the background is unchanged.
- The default resort has no expiry.

## Non-goals

- **No way to clear the default** other than picking another resort. While the default is in the
  saved list, the list never shows first at launch again.
- **No marker in the list** showing which resort is the default.
- **The camera position isn't remembered.** The reopened map is framed on the whole resort, as on
  every open (pan, zoom and rotation are not kept, and F22's camera bounds are untouched).
- **No offline map.** The reopened map still fetches its data, so with no signal it shows "Couldn't
  load map" until F16 keeps resort data on the device.
- **No saving of anything else on screen.** Route points and the list's scroll position belong to
  later features.
- **No syncing across devices** and no account.
- **Favourites (F3) and sorting by distance (F2)** are separate features.

## NFR trigger

**Storage and migration:** this is the app's first piece of user state, a step DECISIONS D5 and the F3
backlog entry had expected F3 to take. /design-feature may take D5 as written (drift, migration 1) or
propose a lighter store for one value. If it goes the second way, it must record that it supersedes
D5. **Launch:** the launch decision adds a local read before the first screen. It stays off the
network and is accepted without a time budget. Nothing else: no security, data-volume or concurrency
effect.

## Simplification levers

- **Most of the cost is setting up user-state storage**, not the remembering itself. This is left to
  the design (see the NFR trigger).
- **Checking the default against the saved list** makes the launch decision wait for the saved list
  to be read. Dropping the check (storing the name and always reopening) is rejected: a resort taken
  out of the list would reopen with a stale name onto a map that can never load.

## UX note

When there is a default resort that's in the saved list, launch lands on its map with no flash of the
list. Everything on the map screen is as today.

## Gate record

User rulings: the default changes only when the skier picks another resort, and there's no expiry
(grilling); show the list and keep the default when no saved list can be read; skip rather than clear
a default that isn't in the saved list; launch shows today's pre-first-screen display, with no time
budget and the network off that path; no marker in the list. Accepted on recommendation (auto): a
failed store is reported in the debug run record only; the name comes from the saved list read at
launch; the design chooses the store against D5; the reinstall claim is dropped; the remaining
non-goals; keep the check against the list.
