import { mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { expect, it } from "vitest";

import { buildResort } from "../../scripts/build/build-resort.ts";
import { readManifest, partPath } from "../../scripts/build/bundle.ts";
import type { Cut } from "../../scripts/build/cut-tiles.ts";
import { lifts, run, runs } from "./openskimap-shapes.ts";

it("builds a resort's bundle: its pistes, with basemap and terrain cut to the pistes' bounds, crediting every source", () => {
  const output = mkdtempSync(join(tmpdir(), "build-resort-"));
  const cuts: Cut[] = [];
  const cut = (request: Cut) => {
    cuts.push(request);
    writeFileSync(request.output, `tiles from ${request.source}`);
  };

  buildResort({
    resortId: "paradiski",
    skiAreaIds: ["area-1"],
    exports: { runs: runs(run({ skiAreaId: "area-1", coordinates: [[6.8, 45.5, 0], [6.9, 45.6, 0]] })), lifts: lifts() },
    output,
    cut,
  });

  const manifest = readManifest(output);
  expect(manifest.bounds).toEqual([6.8, 45.5, 6.9, 45.6]);
  expect(manifest.parts.map((part) => part.role)).toEqual(["pistes", "basemap", "terrain"]);
  expect(manifest.credits).toEqual(["© OpenStreetMap contributors", "OpenSkiMap", "Skimap.org", "Protomaps", "Mapterhorn"]);
  expect(cuts.map(({ bounds }) => bounds)).toEqual([[6.8, 45.5, 6.9, 45.6], [6.8, 45.5, 6.9, 45.6]]);
  const terrain = manifest.parts.find((part) => part.role === "terrain")!;
  expect(readFileSync(partPath(output, terrain.sha256), "utf8")).toBe("tiles from https://download.mapterhorn.com/planet.pmtiles");
});

it("fails, naming the resort, when its ski areas hold no runs", () => {
  expect(() =>
    buildResort({
      resortId: "les-3-vallees",
      skiAreaIds: ["area-1"],
      exports: { runs: runs(run({ skiAreaId: "area-2" })), lifts: lifts() },
      output: mkdtempSync(join(tmpdir(), "build-resort-")),
      cut: () => {},
    }),
  ).toThrow("les-3-vallees: no runs or lifts in its ski areas");
});
