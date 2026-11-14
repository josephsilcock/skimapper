import { expect, it } from "vitest";

import { boundsOf } from "../../scripts/build/bounds.ts";
import { pistes, pistesRun } from "../../scripts/build/pistes-format.ts";

it("a resort's bounds enclose every coordinate of its pistes", () => {
  const resortPistes = pistes([
    pistesRun({ type: "LineString", coordinates: [[6.82, 45.58], [6.83, 45.57]] }, "A", "easy"),
    pistesRun({ type: "LineString", coordinates: [[6.81, 45.575], [6.825, 45.585]] }, "B", "easy"),
  ]);

  expect(boundsOf(resortPistes)).toEqual([6.81, 45.57, 6.83, 45.585]);
});

it("a resort's bounds enclose its run areas too", () => {
  const resortPistes = pistes([
    pistesRun({ type: "LineString", coordinates: [[6.82, 45.58], [6.83, 45.57]] }, "A", "easy"),
    pistesRun({ type: "Polygon", coordinates: [[[6.8, 45.56], [6.81, 45.56], [6.81, 45.59], [6.8, 45.56]]] }, "Bowl", "easy"),
  ]);

  expect(boundsOf(resortPistes)).toEqual([6.8, 45.56, 6.83, 45.59]);
});
