// Regenerates the app's basemap layers (app/assets/map/basemap-layers.json) from Protomaps'
// grayscale flavour, for the tile schema of the build pinned in scripts/build/sources.ts:
//   node scripts/generate-basemap-layers.ts
// Layers that draw icons go (the map has no sprite), and peaks gain grey labels (the flavour
// draws no points of interest); the rest are split where hillshade sits, over land cover, under
// roads, buildings and labels.
import { readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";

import { layers, namedFlavor } from "@protomaps/basemaps";

type Layer = { id: string; type: string; layout?: Record<string, unknown> };

const endpointDir = join(import.meta.dirname, "..");
const version = JSON.parse(readFileSync(join(endpointDir, "node_modules/@protomaps/basemaps/package.json"), "utf8")).version;

const drawn = (layers("basemap", namedFlavor("grayscale"), { lang: "en" }) as Layer[])
  .filter((layer) => layer.type !== "background" && !hasOnlyIcons(layer))
  .map(withoutIcons)
  .concat([peakLabel()]);
const firstAboveHillshade = drawn.findIndex((layer) => layer.id.startsWith("roads_"));

writeFileSync(
  join(endpointDir, "..", "app", "assets", "map", "basemap-layers.json"),
  `${JSON.stringify({ protomapsBasemaps: version, under: drawn.slice(0, firstAboveHillshade), over: drawn.slice(firstAboveHillshade) }, null, 1)}\n`,
);

function peakLabel(): Layer {
  return {
    id: "peak_label",
    type: "symbol",
    source: "basemap",
    "source-layer": "pois",
    filter: ["==", ["get", "kind"], "peak"],
    layout: { "text-field": ["get", "name"], "text-font": ["Noto Sans Italic"], "text-size": 11 },
    paint: { "text-color": "#7a7a7a", "text-halo-color": "#ffffff", "text-halo-width": 1 },
  } as Layer;
}

function hasOnlyIcons(layer: Layer): boolean {
  return layer.type === "symbol" && layer.layout?.["icon-image"] !== undefined && layer.layout?.["text-field"] === undefined;
}

function withoutIcons(layer: Layer): Layer {
  if (!layer.layout?.["icon-image"]) return layer;
  const { "icon-image": _, ...layout } = layer.layout;
  return { ...layer, layout };
}
