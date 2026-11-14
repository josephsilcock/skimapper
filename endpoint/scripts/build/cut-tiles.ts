import { execFileSync } from "node:child_process";

import type { Bounds } from "./bundle.ts";

export type Cut = { source: string; bounds: Bounds; minzoom?: number; maxzoom: number; output: string };
export type Run = (command: string[]) => void;

// Cuts a resort's basemap or terrain out of a planet archive, reading it remotely by byte range.
export function cutTiles({ source, bounds, minzoom, maxzoom, output }: Cut, run: Run = runCommand): void {
  run([
    "pmtiles", "extract", source, output, `--bbox=${bounds.join(",")}`,
    ...(minzoom === undefined ? [] : [`--minzoom=${minzoom}`]),
    `--maxzoom=${maxzoom}`,
  ]);
}

const runCommand: Run = ([command, ...args]) => {
  execFileSync(command, args, { stdio: ["ignore", "inherit", "inherit"] });
};
