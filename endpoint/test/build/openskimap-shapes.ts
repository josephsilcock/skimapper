import type { GeoJSONFeatureCollection, OpenSkiMapFeature } from "../../scripts/build/select-pistes.ts";

// Builders for features shaped like OpenSkiMap's runs.geojson and lifts.geojson exports.
type RunOptions = {
  name?: string | null;
  difficulty?: string | null;
  skiAreaId?: string;
  status?: string;
  uses?: string[];
  geometryType?: "LineString" | "Polygon";
  coordinates?: unknown;
};

export const run = ({
  name = "A run",
  difficulty = "easy",
  skiAreaId = "area-1",
  status = "operating",
  uses = ["downhill"],
  geometryType = "LineString",
  coordinates = [[6.8, 45.5, 2000], [6.81, 45.49, 1900]],
}: RunOptions = {}): OpenSkiMapFeature => ({
  type: "Feature",
  geometry: { type: geometryType, coordinates },
  properties: {
    id: `run-${name}`,
    type: "run",
    name,
    uses,
    status,
    difficulty,
    ref: null,
    grooming: null,
    skiAreas: [{ type: "Feature", properties: { id: skiAreaId, name: "Area", type: "skiArea" } }],
  },
});

export const runs = (...features: OpenSkiMapFeature[]): GeoJSONFeatureCollection => ({
  type: "FeatureCollection",
  features,
});

export const lifts = (...features: OpenSkiMapFeature[]): GeoJSONFeatureCollection => ({
  type: "FeatureCollection",
  features,
});
