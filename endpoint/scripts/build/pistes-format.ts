// Single home for the pistes part's format: what the build writes and the app's style reads.
export type Pistes = { type: "FeatureCollection"; features: PistesFeature[] };
export type PistesGeometry = { type: "LineString" | "Polygon"; coordinates: Position2D[] | Position2D[][] };
export type Position2D = [number, number];
export type PistesFeature = {
  type: "Feature";
  geometry: PistesGeometry;
  properties: { kind: "run"; name: string | null; difficulty: string | null };
};

export const pistes = (features: PistesFeature[]): Pistes => ({ type: "FeatureCollection", features });

export const pistesRun = (geometry: PistesGeometry, name: string | null, difficulty: string | null): PistesFeature => ({
  type: "Feature",
  geometry,
  properties: { kind: "run", name, difficulty },
});

export const pistesPartBytes = (part: Pistes): Uint8Array => new TextEncoder().encode(JSON.stringify(part));
