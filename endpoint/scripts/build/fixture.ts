import { mkdtempSync, readFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

import { boundsOf } from "./bounds.ts";
import type { Bounds, BundleContents } from "./bundle.ts";
import { writeBundle } from "./bundle.ts";
import { cutTiles } from "./cut-tiles.ts";
import { pistesPartBytes, type Pistes } from "./pistes-format.ts";
import { selectPistes, type GeoJSONFeatureCollection } from "./select-pistes.ts";
import { mapterhornPlanet, protomapsBuild, terrainMaxzoom } from "./sources.ts";

// The committed fixture resort that widget and E2E tests use: the build's output over a small
// OpenSkiMap-shaped sample, with a tiny real cut of the basemap and terrain.
const endpointDir = join(import.meta.dirname, "..", "..");
const sampleDir = join(endpointDir, "test", "build", "sample");
const sampleSkiAreaIds = ["sample-ski-area"];
// Only the zooms a skier sees a few km² at, so the committed parts stay small.
const fixtureZooms = { minzoom: 11, basemapMaxzoom: 13 };

export const fixtureBundleDir = join(endpointDir, "fixtures", "resort-bundle");

export const fixturePistes = (): Pistes =>
  selectPistes({ runs: sample("runs"), lifts: sample("lifts") }, sampleSkiAreaIds);

export function writeFixtureBundle(): void {
  const pistes = fixturePistes();
  const bounds = boundsOf(pistes);
  writeBundle(fixtureBundleDir, {
    bounds,
    credits: [],
    parts: [
      { role: "pistes", bytes: pistesPartBytes(pistes) },
      ...cutBasemapAndTerrain(bounds),
    ],
  });
}

function cutBasemapAndTerrain(bounds: Bounds): BundleContents["parts"] {
  const scratch = mkdtempSync(join(tmpdir(), "fixture-cut-"));
  const basemap = join(scratch, "basemap.pmtiles");
  const terrain = join(scratch, "terrain.pmtiles");
  const { minzoom, basemapMaxzoom } = fixtureZooms;
  cutTiles({ source: protomapsBuild, bounds, minzoom, maxzoom: basemapMaxzoom, output: basemap });
  cutTiles({ source: mapterhornPlanet, bounds, minzoom, maxzoom: terrainMaxzoom, output: terrain });
  return [
    { role: "basemap", bytes: readFileSync(basemap) },
    { role: "terrain", bytes: readFileSync(terrain) },
  ];
}

const sample = (name: string): GeoJSONFeatureCollection =>
  JSON.parse(readFileSync(join(sampleDir, `${name}.geojson`), "utf8"));
