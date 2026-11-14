import { expect, it } from "vitest";

import { cutTiles } from "../../scripts/build/cut-tiles.ts";

it("cuts only the zoom levels asked for, when a minimum is given", () => {
  const commands: string[][] = [];

  cutTiles(
    { source: "planet.pmtiles", bounds: [6.81, 45.57, 6.83, 45.585], minzoom: 11, maxzoom: 13, output: "basemap.pmtiles" },
    (command) => commands.push(command),
  );

  expect(commands[0]).toContain("--minzoom=11");
});

it("cuts a tile archive to the resort's bounds and a zoom limit with pmtiles extract", () => {
  const commands: string[][] = [];

  cutTiles(
    { source: "https://tiles.example/planet.pmtiles", bounds: [6.81, 45.57, 6.83, 45.585], maxzoom: 12, output: "/out/terrain.pmtiles" },
    (command) => commands.push(command),
  );

  expect(commands).toEqual([
    ["pmtiles", "extract", "https://tiles.example/planet.pmtiles", "/out/terrain.pmtiles", "--bbox=6.81,45.57,6.83,45.585", "--maxzoom=12"],
  ]);
});
