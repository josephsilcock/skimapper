import { expect, it } from "vitest";

import { checkedResortAreas, skiAreaIdsFor } from "../../scripts/build/resort-areas.ts";

const skiArea = (id: string, sources: { type: string; id: string | number }[]) => ({
  type: "Feature" as const,
  geometry: { type: "Point", coordinates: [6.8, 45.5] },
  properties: { id, type: "skiArea", name: id, sources },
});

it("finds this build's ski areas by their stable source ids", () => {
  const skiAreas = {
    type: "FeatureCollection" as const,
    features: [
      skiArea("hash-1", [{ type: "openstreetmap", id: "relation/1" }, { type: "skimap.org", id: 1079 }]),
      skiArea("hash-2", [{ type: "skimap.org", id: 1079 }]),
      skiArea("hash-3", [{ type: "skimap.org", id: 1080 }]),
    ],
  };

  expect(skiAreaIdsFor([{ type: "skimap.org", id: 1079 }], skiAreas)).toEqual(["hash-1", "hash-2"]);
});

it("refuses resort areas that name a different set of resorts than the catalogue", () => {
  expect(() =>
    checkedResortAreas({ paradiski: [{ type: "skimap.org", id: 1080 }], extra: [] }, ["paradiski", "les-3-vallees"]),
  ).toThrow(/les-3-vallees.*extra|extra.*les-3-vallees/);
});
