import type { Bounds } from "./bundle.ts";
import type { Pistes, PistesGeometry, Position2D } from "./pistes-format.ts";

// "The whole resort": the box the app frames on, and what the build's cut area is padded from.
export function boundsOf(resortPistes: Pistes): Bounds {
  const positions = resortPistes.features.flatMap((feature) => positionsOf(feature.geometry));
  const lons = positions.map(([lon]) => lon);
  const lats = positions.map(([, lat]) => lat);
  return [Math.min(...lons), Math.min(...lats), Math.max(...lons), Math.max(...lats)];
}

const positionsOf = ({ type, coordinates }: PistesGeometry): Position2D[] =>
  type === "Polygon" ? (coordinates as Position2D[][]).flat() : (coordinates as Position2D[]);

// The area the basemap and terrain are cut to: the bounds and a tenth of their span beyond each
// side, so the framing's padding around the resort still shows the map.
export function cutArea([west, south, east, north]: Bounds): Bounds {
  const lonMargin = (east - west) * 0.1;
  const latMargin = (north - south) * 0.1;
  return [west - lonMargin, south - latMargin, east + lonMargin, north + latMargin];
}
