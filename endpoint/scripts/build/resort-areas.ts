import type { GeoJSONFeatureCollection, OpenSkiMapFeature } from "./select-pistes.ts";

// A ski area as its source names it (an OSM relation, a Skimap.org id): stable across builds,
// unlike OpenSkiMap's own ids.
export type SourceRef = { type: string; id: string | number };

// This build's OpenSkiMap ids for the ski areas any of [refs] names.
export function skiAreaIdsFor(refs: SourceRef[], skiAreas: GeoJSONFeatureCollection): string[] {
  const named = (source: SourceRef) => refs.some((ref) => ref.type === source.type && ref.id === source.id);
  return skiAreas.features.filter((area) => sourcesOf(area).some(named)).map((area) => area.properties.id as string);
}

const sourcesOf = (area: OpenSkiMapFeature): SourceRef[] => (area.properties.sources as SourceRef[] | undefined) ?? [];

export type ResortAreas = Record<string, SourceRef[]>;

// The catalogue is the one home of resort ids: the resort-areas file must name exactly its set.
export function checkedResortAreas(resortAreas: ResortAreas, catalogueIds: string[]): ResortAreas {
  const named = Object.keys(resortAreas);
  const missing = catalogueIds.filter((id) => !named.includes(id));
  const unknown = named.filter((id) => !catalogueIds.includes(id));
  if (missing.length || unknown.length) {
    throw new Error(`resort areas don't match the catalogue: missing ${missing.join(", ") || "none"}; not in the catalogue ${unknown.join(", ") || "none"}`);
  }
  return resortAreas;
}
