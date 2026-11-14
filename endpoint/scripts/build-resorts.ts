// Builds each curated resort's bundle into build-output/<resort id> from OpenSkiMap's exports
// (downloaded into build-output/downloads once), Protomaps and Mapterhorn:
//   node scripts/build-resorts.ts [--resort <id>]
// Needs the pmtiles command-line tool.
import { createReadStream, createWriteStream, existsSync, mkdirSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { createInterface } from "node:readline";
import { Readable } from "node:stream";
import type { ReadableStream } from "node:stream/web";
import { pipeline } from "node:stream/promises";
import { parseArgs } from "node:util";

import { buildResort } from "./build/build-resort.ts";
import { resortAreas } from "./build/curated.ts";
import { skiAreaIdsFor } from "./build/resort-areas.ts";
import { belongsTo, type GeoJSONFeatureCollection, type OpenSkiMapFeature } from "./build/select-pistes.ts";

const buildOutputDir = join(import.meta.dirname, "..", "build-output");
const downloadsDir = join(buildOutputDir, "downloads");
const openSkiMapExports = "https://tiles.openskimap.org/geojson";

const { values } = parseArgs({ options: { resort: { type: "string" } } });
const areas = resortAreas();
const resortIds = values.resort ? [values.resort] : Object.keys(areas);

const skiAreas = JSON.parse(readFileSync(await downloaded("ski_areas"), "utf8")) as GeoJSONFeatureCollection;
const skiAreaIds = new Map(resortIds.map((resortId) => [resortId, skiAreasOf(resortId)]));
// The exports are too large to hold whole, so only features of the resorts being built are read.
const ofAnyResort = belongsTo(new Set([...skiAreaIds.values()].flat()));
const exports = { runs: await featuresOf("runs", ofAnyResort), lifts: await featuresOf("lifts", ofAnyResort) };

for (const [resortId, ids] of skiAreaIds) {
  buildResort({ resortId, skiAreaIds: ids, exports, output: join(buildOutputDir, resortId) });
  console.log(`${resortId}: built into build-output/${resortId}`);
}

function skiAreasOf(resortId: string): string[] {
  const refs = areas[resortId] ?? fail(`${resortId}: not a curated resort`);
  const ids = skiAreaIdsFor(refs, skiAreas);
  if (ids.length === 0) fail(`${resortId}: no OpenSkiMap ski area matches ${JSON.stringify(refs)}`);
  return ids;
}

// OpenSkiMap writes one feature per line.
async function featuresOf(name: string, keep: (feature: OpenSkiMapFeature) => boolean): Promise<GeoJSONFeatureCollection> {
  const features: OpenSkiMapFeature[] = [];
  for await (const line of createInterface({ input: createReadStream(await downloaded(name)) })) {
    if (!line.startsWith('{"type":"Feature"')) continue;
    const feature = JSON.parse(line) as OpenSkiMapFeature;
    if (keep(feature)) features.push(feature);
  }
  return { type: "FeatureCollection", features };
}

async function downloaded(name: string): Promise<string> {
  const file = join(downloadsDir, `${name}.geojson`);
  if (existsSync(file)) return file;
  mkdirSync(downloadsDir, { recursive: true });
  const response = await fetch(`${openSkiMapExports}/${name}.geojson`);
  if (!response.ok || !response.body) fail(`download ${name}: HTTP ${response.status}`);
  await pipeline(Readable.fromWeb(response.body as unknown as ReadableStream), createWriteStream(file));
  return file;
}

function fail(message: string): never {
  throw new Error(message);
}
