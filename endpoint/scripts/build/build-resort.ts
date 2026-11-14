import { mkdtempSync, readFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

import { boundsOf } from "./bounds.ts";
import { writeBundle, type Bounds, type BundleContents } from "./bundle.ts";
import { cutTiles, type Cut } from "./cut-tiles.ts";
import { pistesPartBytes } from "./pistes-format.ts";
import { selectPistes, type OpenSkiMapExports } from "./select-pistes.ts";
import { credits, mapterhornPlanet, protomapsBuild, terrainMaxzoom } from "./sources.ts";

export type Zooms = { minzoom?: number; basemapMaxzoom: number };
export type ResortBuild = {
  resortId: string;
  skiAreaIds: string[];
  exports: OpenSkiMapExports;
  output: string;
  zooms?: Zooms;
  cut?: (cut: Cut) => void;
};

// Protomaps' deepest zoom.
const allZooms: Zooms = { basemapMaxzoom: 15 };

// One resort's bundle: its pistes, then its basemap and terrain cut to the pistes' bounds.
export function buildResort({ resortId, skiAreaIds, exports, output, zooms = allZooms, cut = cutTiles }: ResortBuild): void {
  const pistes = selectPistes(exports, skiAreaIds);
  if (pistes.features.length === 0) throw new Error(`${resortId}: no runs or lifts in its ski areas`);
  const bounds = boundsOf(pistes);
  writeBundle(output, {
    bounds,
    credits,
    parts: [{ role: "pistes", bytes: pistesPartBytes(pistes) }, ...cutBasemapAndTerrain(bounds, zooms, cut)],
  });
}

function cutBasemapAndTerrain(bounds: Bounds, { minzoom, basemapMaxzoom }: Zooms, cut: (cut: Cut) => void): BundleContents["parts"] {
  const scratch = mkdtempSync(join(tmpdir(), "resort-cut-"));
  const basemap = join(scratch, "basemap.pmtiles");
  const terrain = join(scratch, "terrain.pmtiles");
  cut({ source: protomapsBuild, bounds, minzoom, maxzoom: basemapMaxzoom, output: basemap });
  cut({ source: mapterhornPlanet, bounds, minzoom, maxzoom: terrainMaxzoom, output: terrain });
  return [
    { role: "basemap", bytes: readFileSync(basemap) },
    { role: "terrain", bytes: readFileSync(terrain) },
  ];
}
