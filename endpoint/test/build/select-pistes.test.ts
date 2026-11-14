import { expect, it } from "vitest";

import { selectPistes } from "../../scripts/build/select-pistes.ts";
import { lifts, run, runs } from "./openskimap-shapes.ts";

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
