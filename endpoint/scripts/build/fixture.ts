import { readFileSync } from "node:fs";
import { join } from "node:path";

import { buildResort, type Zooms } from "./build-resort.ts";
import type { Pistes } from "./pistes-format.ts";
import { selectPistes, type GeoJSONFeatureCollection, type OpenSkiMapExports } from "./select-pistes.ts";

// The committed fixture resort that widget and E2E tests use: the build's output over a small
// OpenSkiMap-shaped sample, with a tiny real cut of the basemap and terrain.
const endpointDir = join(import.meta.dirname, "..", "..");
const sampleDir = join(endpointDir, "test", "build", "sample");
const sampleSkiAreaIds = ["sample-ski-area"];

// Only the zooms a skier sees a few km² at, so the committed parts stay small.
const fixtureZooms: Zooms = { minzoom: 11, basemapMaxzoom: 13 };

export const fixtureBundleDir = join(endpointDir, "fixtures", "resort-bundle");

export const fixturePistes = (): Pistes => selectPistes(sampleExports(), sampleSkiAreaIds);

export function writeFixtureBundle(): void {
  buildResort({ resortId: "fixture", skiAreaIds: sampleSkiAreaIds, exports: sampleExports(), output: fixtureBundleDir, zooms: fixtureZooms });
}

const sampleExports = (): OpenSkiMapExports => ({ runs: sample("runs"), lifts: sample("lifts") });

const sample = (name: string): GeoJSONFeatureCollection =>
  JSON.parse(readFileSync(join(sampleDir, `${name}.geojson`), "utf8"));
