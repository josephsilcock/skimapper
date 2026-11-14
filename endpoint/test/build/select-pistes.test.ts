import { expect, it } from "vitest";

import { selectPistes } from "../../scripts/build/select-pistes.ts";
import { lift, lifts, run, runs } from "./openskimap-shapes.ts";

it("writes a resort's downhill operating run with its name, difficulty and 2D coordinates", () => {
  const pistes = selectPistes(
    { runs: runs(run({ name: "Mont Blanc", difficulty: "easy", skiAreaId: "area-1", coordinates: [[6.8, 45.5, 2000], [6.81, 45.49, 1900]] })), lifts: lifts() },
    ["area-1"],
  );

  expect(pistes).toEqual({
    type: "FeatureCollection",
    features: [
      {
        type: "Feature",
        geometry: { type: "LineString", coordinates: [[6.8, 45.5], [6.81, 45.49]] },
        properties: { kind: "run", name: "Mont Blanc", difficulty: "easy" },
      },
    ],
  });
});

it("leaves out runs that belong to none of the resort's ski areas", () => {
  const pistes = selectPistes(
    { runs: runs(run({ name: "Ours", skiAreaId: "area-1" }), run({ name: "Theirs", skiAreaId: "area-2" })), lifts: lifts() },
    ["area-1"],
  );

  expect(pistes.features.map((feature) => feature.properties.name)).toEqual(["Ours"]);
});

it("writes a run area as a polygon with 2D rings", () => {
  const ring = [[6.8, 45.5, 2000], [6.81, 45.5, 2000], [6.81, 45.51, 2000], [6.8, 45.5, 2000]];

  const pistes = selectPistes(
    { runs: runs(run({ name: "Bowl", geometryType: "Polygon", coordinates: [ring] })), lifts: lifts() },
    ["area-1"],
  );

  expect(pistes.features[0].geometry).toEqual({
    type: "Polygon",
    coordinates: [[[6.8, 45.5], [6.81, 45.5], [6.81, 45.51], [6.8, 45.5]]],
  });
});

it("leaves out nordic, ski-touring and sledging runs", () => {
  const pistes = selectPistes(
    {
      runs: runs(
        run({ name: "Downhill", uses: ["downhill"] }),
        run({ name: "Nordic", uses: ["nordic"] }),
        run({ name: "Touring", uses: ["skitour"] }),
        run({ name: "Sledging", uses: ["sled"] }),
        run({ name: "Shared", uses: ["downhill", "nordic"] }),
      ),
      lifts: lifts(),
    },
    ["area-1"],
  );

  expect(pistes.features.map((feature) => feature.properties.name)).toEqual(["Downhill", "Shared"]);
});

it("leaves out proposed, planned, under construction, disused and abandoned runs", () => {
  const pistes = selectPistes(
    {
      runs: runs(
        ...["operating", "proposed", "planned", "construction", "disused", "abandoned"].map((status) =>
          run({ name: status, status }),
        ),
      ),
      lifts: lifts(),
    },
    ["area-1"],
  );

  expect(pistes.features.map((feature) => feature.properties.name)).toEqual(["operating"]);
});

it("writes a resort's operating lift with its name, lift type and 2D coordinates", () => {
  const pistes = selectPistes(
    { runs: runs(), lifts: lifts(lift({ name: "Chair", liftType: "chair_lift", coordinates: [[6.81, 45.49, 1900], [6.8, 45.5, 2000]] })) },
    ["area-1"],
  );

  expect(pistes.features).toEqual([
    {
      type: "Feature",
      geometry: { type: "LineString", coordinates: [[6.81, 45.49], [6.8, 45.5]] },
      properties: { kind: "lift", name: "Chair", liftType: "chair_lift" },
    },
  ]);
});

it("leaves out proposed, planned, under construction, disused and abandoned lifts", () => {
  const pistes = selectPistes(
    {
      runs: runs(),
      lifts: lifts(
        ...["operating", "proposed", "planned", "construction", "disused", "abandoned"].map((status) =>
          lift({ name: status, status }),
        ),
      ),
    },
    ["area-1"],
  );

  expect(pistes.features.map((feature) => feature.properties.name)).toEqual(["operating"]);
});

it("writes a run whose difficulty OpenSkiMap omits with a null difficulty", () => {
  const unrated = run({ name: "Unrated" });
  delete unrated.properties.difficulty;

  const pistes = selectPistes({ runs: runs(unrated), lifts: lifts() }, ["area-1"]);

  expect(pistes.features[0].properties).toEqual({ kind: "run", name: "Unrated", difficulty: null });
});
