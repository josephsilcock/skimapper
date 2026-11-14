import { readFileSync } from "node:fs";
import { join } from "node:path";

import { writeBundle } from "./bundle.ts";
import { pistesPartBytes, type Pistes } from "./pistes-format.ts";
import { selectPistes, type GeoJSONFeatureCollection } from "./select-pistes.ts";

// The committed fixture resort that widget and E2E tests use: the build's output over a small
// OpenSkiMap-shaped sample.
const endpointDir = join(import.meta.dirname, "..", "..");
const sampleDir = join(endpointDir, "test", "build", "sample");
const sampleSkiAreaIds = ["sample-ski-area"];

export const fixtureBundleDir = join(endpointDir, "fixtures", "resort-bundle");

export const fixturePistes = (): Pistes =>
  selectPistes({ runs: sample("runs"), lifts: sample("lifts") }, sampleSkiAreaIds);

export function writeFixtureBundle(): void {
  writeBundle(fixtureBundleDir, {
    bounds: [6.81, 45.57, 6.83, 45.585],
    credits: [],
    parts: [{ role: "pistes", bytes: pistesPartBytes(fixturePistes()) }],
  });
}

const sample = (name: string): GeoJSONFeatureCollection =>
  JSON.parse(readFileSync(join(sampleDir, `${name}.geojson`), "utf8"));
