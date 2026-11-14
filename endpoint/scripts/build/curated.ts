import { readFileSync } from "node:fs";
import { join } from "node:path";

import { checkedResortAreas, type ResortAreas } from "./resort-areas.ts";

const catalogueDir = join(import.meta.dirname, "..", "..", "catalogue");

export type CuratedResort = { id: string; name: string; countries: string[]; centre: { lat: number; lon: number } };

// The curated catalogue (the one home of resort ids) and the ski areas each resort is made of.
export const curatedCatalogue = (): { resorts: CuratedResort[] } =>
  JSON.parse(readFileSync(join(catalogueDir, "curated.json"), "utf8"));

export const curatedResortIds = (): string[] => curatedCatalogue().resorts.map((resort) => resort.id);

export const resortAreas = (): ResortAreas =>
  checkedResortAreas(JSON.parse(readFileSync(join(catalogueDir, "resort-areas.json"), "utf8")), curatedResortIds());
