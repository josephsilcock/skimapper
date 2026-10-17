# C4 — Initial technical decisions and walking skeleton

## Intent

Every feature in the backlog is blocked on the same missing foundation. There is no tech stack, architecture or hosting choice for the mobile app or the service or data endpoint behind it, and every test and run command in `docs/PIPELINE.md` is still TBD. C4 makes those choices deliberately: options with pros and cons, decided at the design gate and recorded with the roads not taken. It then proves them with a **walking skeleton**. That skeleton is a placeholder app on iOS and Android that fetches a message from a locally run service or data endpoint and renders a bundled offline map tile. Every PIPELINE role is filled in, and a full sweep that includes E2E tests on both platforms runs green. F1 onwards then starts with the integration risk and the riskiest stack choice (offline maps on both platforms) already paid down.

**Demo sentence:** *The developer runs the dev-app command for each platform and sees a placeholder SkiMapper screen, on both the iOS simulator and the Android emulator. The screen shows a message it fetched from the locally running service or data endpoint, plus an offline map tile rendered by the chosen map library. The developer runs the full sweep and sees every layer, including an E2E test on each platform, pass.*

"Service or data endpoint" is deliberate. The backend might be a long-running server, or a scheduled job publishing versioned static files to storage or a CDN. That choice belongs to `/design-feature`, weighed against F20 and C1/C2.

## Constraints the choices must honour

These are requirements on the decisions, confirmed during grilling. They are not the decisions themselves, which belong to `/design-feature`.

- **One codebase for iOS and Android**, both proven from the start.
- **Offline-first on the device** (F16/F17). Resort data, the vector background map and the terrain shading must work with no signal once a resort is saved.
- **Route planning runs on the device** (F16), so the routing engine lives in the app.
- **The skier's location never leaves the device** (F2).
- **Resort data comes from open sources refreshed daily** (F20, presumably OpenStreetMap / OpenSkiMap). C4 names the source and where the daily refresh runs, but builds no ingestion.
- **Free tier preferred** for hosting and services wherever possible.
- **Licences and terms must allow storing data, tiles and terrain offline on the device.** For example, OSM's ODbL attribution and share-alike obligations, and tile/terrain providers that forbid bulk offline download.
- **No language preference.** Each decision is presented at the design gate as options with pros and cons.

## Evaluation criteria (NFRs)

Every option is judged against these as well as the constraints:

- offline storage volume per resort for vector tiles and terrain (F17/F18);
- on-device routing performance on resort-sized graphs (F11);
- free-tier limits for the daily refresh and status traffic (F6/F19/F20);
- licence and terms compatibility with offline storage on the device.

## Acceptance criteria

```gherkin
Scenario: The technical decisions are recorded with their alternatives
  Given C4 is finished
  When a reader opens docs/DECISIONS.md and docs/ARCHITECTURE.md
  Then each of these has a recorded choice, the rejected alternatives and why:
    | mobile app stack (iOS + Android, one codebase)                 |
    | service or data endpoint stack                                 |
    | overall architecture (what runs on device vs service/endpoint) |
    | hosting for the service/endpoint and the daily refresh         |
    | resort data source                                             |
    | live lift and run status source                                |
    | offline map and terrain approach                               |
    | on-device structured storage                                   |
    | routing engine and graph format                                |
    | test layers and E2E tooling                                    |
  And each choice is checked against every constraint and every evaluation criterion above
  And the hosting decision records that its free-tier fit is unverified until the first deploy

Scenario Outline: The skeleton app shows a message controlled by the service
  Given the service or data endpoint is running locally and serving a message chosen by the test
  When the developer launches the dev app on <platform>
  Then the placeholder SkiMapper screen shows that same message

  Examples:
    | platform          |
    | iOS simulator     |
    | Android emulator  |

Scenario Outline: The chosen map library renders offline
  Given the device has no network access to any map or tile provider
  When the developer launches the dev app on <platform>
  Then the screen shows a vector tile bundled with the app, rendered by the chosen map library (no styling, no real resort data)

  Examples:
    | platform          |
    | iOS simulator     |
    | Android emulator  |

Scenario Outline: The skeleton fails visibly when the service is unreachable
  Given the service or data endpoint is not running
  When the developer launches the dev app on <platform>
  Then within a few seconds the screen says the service could not be reached, rather than a blank screen, an endless spinner, or a placeholder that looks like success

  Examples:
    | platform          |
    | iOS simulator     |
    | Android emulator  |

Scenario: Every pipeline role has a working command
  Given C4 is finished
  When a reader opens docs/PIPELINE.md
  Then fast tests, feature-scoped slow tests, feature-scoped E2E, full sweep, results dir and dev app each name a real command
  And the dev app is one command taking a platform argument (iOS or Android)
  And each command runs successfully against the skeleton
  And the full sweep runs every test layer, including the E2E tests on both platforms, and passes

Scenario: The full sweep cannot go silently green
  Given any one of these holds:
    | a test in any layer is failing        |
    | a layer runs no tests                 |
    | a target simulator or emulator is unavailable |
  When the developer runs the full sweep
  Then the sweep exits with a failure and names the layer (and platform) responsible
```

## Non-goals / out of scope

- **No production deployment.** Hosting is chosen and recorded, but the skeleton service or data endpoint runs only locally. Deploying it is picked up when the first feature needs a reachable backend.
- **No CI.** That is captured as **C5**.
- No app-store, TestFlight or other release distribution.
- No auth, rate limiting or abuse protection (C1/C2).
- No monitoring or failure reporting (C3).
- No real resort data or ingestion, no map rendering beyond the single bundled-tile spike, and no offline storage or routing code. F1, F5, F11, F16 and F20 build those. C4 only *chooses* the approach for them.
- No theming or design system (F21). The placeholder screen is unstyled beyond legibility.
- No app identity work (icons, splash screens, bundle names beyond what the tooling needs).

## NFR trigger

The skeleton itself has no performance, security, volume or concurrency implications. **The decisions do.** See *Evaluation criteria* above: storage volume, routing performance, free-tier limits and licensing are explicit criteria for every option. Free-tier fit can only be checked on paper until something is deployed.

## Simplification levers

- **Proving both platforms in E2E** is the main cost driver: two simulators or emulators, two device setups, and a slower sweep. The lever would be E2E on one platform plus a manual Android launch, but that was declined in grilling ("iOS and Android from the start"). Recorded here so the cost is visible.
- **App-to-service call in the skeleton.** Dropping it (an app-only skeleton) would halve the setup, but it gives up proving the app/backend seam, which is the integration risk C4 exists to retire. Not taken.

## UX note

A single placeholder screen showing the app name, the message from the service or data endpoint (or a "service could not be reached" message), and the bundled offline map tile. It has no navigation and no styling decisions.

## Open notes for design

- **Data-contract versioning.** The review suggested that whatever the app saves from the backend should carry a version or schema field from day one, so F19/F20 can update saved copies without an app update. This was not ruled on at the spec gate. `/design-feature` should raise it as a decision.

## Assumptions

- Preflight: `.idea/` is untracked. The user will add a `.gitignore` once the stack is chosen, so it is left alone until then.
