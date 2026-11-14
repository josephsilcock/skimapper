import { pistes, pistesLift, pistesRun, type Pistes, type PistesGeometry, type Position2D } from "./pistes-format.ts";

export type OpenSkiMapExports = { runs: GeoJSONFeatureCollection; lifts: GeoJSONFeatureCollection };
export type GeoJSONFeatureCollection = { type: "FeatureCollection"; features: OpenSkiMapFeature[] };
export type OpenSkiMapFeature = {
  type: "Feature";
  geometry: { type: string; coordinates: unknown };
  properties: Record<string, unknown>;
};

// The build's selection: which of OpenSkiMap's features a resort's pistes part holds.
export function selectPistes(exports: OpenSkiMapExports, skiAreaIds: readonly string[]): Pistes {
  const ofResort = belongsTo(new Set(skiAreaIds));
  const drawnRun = (run: OpenSkiMapFeature) => ofResort(run) && isOperating(run) && isDownhill(run);
  const drawnLift = (lift: OpenSkiMapFeature) => ofResort(lift) && isOperating(lift);
  return pistes([
    ...exports.runs.features.filter(drawnRun).map(asPistesRun),
    ...exports.lifts.features.filter(drawnLift).map(asPistesLift),
  ]);
}

const isOperating = (feature: OpenSkiMapFeature): boolean => feature.properties.status === "operating";

const isDownhill = (run: OpenSkiMapFeature): boolean =>
  ((run.properties.uses as string[] | undefined) ?? []).includes("downhill");

// Membership: a feature belongs to a resort when it lies in any of the resort's ski areas.
export const belongsTo = (skiAreaIds: Set<string>) => (feature: OpenSkiMapFeature): boolean =>
  ((feature.properties.skiAreas as { properties: { id: string } }[] | undefined) ?? []).some((area) =>
    skiAreaIds.has(area.properties.id),
  );

const asPistesRun = (feature: OpenSkiMapFeature) =>
  pistesRun(flattened(feature.geometry), nameOf(feature), feature.properties.difficulty as string | null);

const asPistesLift = (feature: OpenSkiMapFeature) =>
  pistesLift(flattened(feature.geometry), nameOf(feature), (feature.properties.liftType as string | null) ?? null);

const nameOf = (feature: OpenSkiMapFeature): string | null => (feature.properties.name as string | null) ?? null;

function flattened({ type, coordinates }: OpenSkiMapFeature["geometry"]): PistesGeometry {
  if (type === "LineString") return { type, coordinates: (coordinates as number[][]).map(position2D) };
  if (type === "Polygon") return { type, coordinates: (coordinates as number[][][]).map((ring) => ring.map(position2D)) };
  throw new Error(`unexpected run geometry ${type}`);
}

const position2D = ([lon, lat]: number[]): Position2D => [lon, lat];
