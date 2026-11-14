// Regenerates the app's basemap layers (app/assets/map/basemap-layers.json) from Protomaps'
// grayscale flavour, for the tile schema of the build pinned in scripts/build/sources.ts:
//   node scripts/generate-basemap-layers.ts
// Layers that draw icons go (the map has no sprite); the rest are split where hillshade sits,
// over land cover and water, under roads, buildings and labels.
import { readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";

import { layers, namedFlavor } from "@protomaps/basemaps";

type Layer = { id: string; type: string; layout?: Record<string, unknown> };

const endpointDir = join(import.meta.dirname, "..");
const version = JSON.parse(readFileSync(join(endpointDir, "node_modules/@protomaps/basemaps/package.json"), "utf8")).version;

const drawn = (layers("basemap", namedFlavor("grayscale"), { lang: "en" }) as Layer[])
  .filter((layer) => layer.type !== "background" && !hasOnlyIcons(layer))
  .map(withoutIcons);
const firstAboveHillshade = drawn.findIndex((layer) => layer.id.startsWith("roads_"));

writeFileSync(
  join(endpointDir, "..", "app", "assets", "map", "basemap-layers.json"),
  `${JSON.stringify({ protomapsBasemaps: version, under: drawn.slice(0, firstAboveHillshade), over: drawn.slice(firstAboveHillshade) }, null, 1)}\n`,
);

function hasOnlyIcons(layer: Layer): boolean {
  return layer.type === "symbol" && layer.layout?.["icon-image"] !== undefined && layer.layout?.["text-field"] === undefined;
}

function withoutIcons(layer: Layer): Layer {
  if (!layer.layout?.["icon-image"]) return layer;
  const { "icon-image": _, ...layout } = layer.layout;
  return { ...layer, layout };
}
