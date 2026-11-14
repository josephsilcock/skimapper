import { pistes, pistesRun, type Pistes, type PistesGeometry, type Position2D } from "./pistes-format.ts";

export type OpenSkiMapExports = { runs: GeoJSONFeatureCollection; lifts: GeoJSONFeatureCollection };
export type GeoJSONFeatureCollection = { type: "FeatureCollection"; features: OpenSkiMapFeature[] };
export type OpenSkiMapFeature = {
  type: "Feature";
  geometry: { type: string; coordinates: unknown };
  properties: Record<string, unknown>;
};

// The build's selection: which of OpenSkiMap's features a resort's pistes part holds.
export function selectPistes(exports: OpenSkiMapExports, _skiAreaIds: readonly string[]): Pistes {
  return pistes(exports.runs.features.map(asPistesRun));
}

const asPistesRun = (feature: OpenSkiMapFeature) =>
  pistesRun(flattened(feature.geometry), nameOf(feature), feature.properties.difficulty as string | null);

const nameOf = (feature: OpenSkiMapFeature): string | null => (feature.properties.name as string | null) ?? null;

function flattened({ type, coordinates }: OpenSkiMapFeature["geometry"]): PistesGeometry {
  if (type === "LineString") return { type, coordinates: (coordinates as number[][]).map(position2D) };
  throw new Error(`unexpected run geometry ${type}`);
}

const position2D = ([lon, lat]: number[]): Position2D => [lon, lat];
