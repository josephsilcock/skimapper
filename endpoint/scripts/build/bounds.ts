import type { Bounds } from "./bundle.ts";
import type { Pistes, PistesGeometry, Position2D } from "./pistes-format.ts";

// "The whole resort": the box the app frames on, and the area the build cuts the basemap and
// terrain to.
export function boundsOf(resortPistes: Pistes): Bounds {
  const positions = resortPistes.features.flatMap((feature) => positionsOf(feature.geometry));
  const lons = positions.map(([lon]) => lon);
  const lats = positions.map(([, lat]) => lat);
  return [Math.min(...lons), Math.min(...lats), Math.max(...lons), Math.max(...lats)];
}

const positionsOf = ({ coordinates }: PistesGeometry): Position2D[] => coordinates as Position2D[];
