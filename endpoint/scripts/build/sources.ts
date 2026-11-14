// Where the build reads each source. The Protomaps build is pinned: its tile schema is the one
// the app's committed basemap layers assume (app/assets/map/basemap-layers.json).
export const protomapsBuild = "https://build.protomaps.com/20261113.pmtiles";
export const mapterhornPlanet = "https://download.mapterhorn.com/planet.pmtiles";

// Mapterhorn's planet archive stops at zoom 12.
export const terrainMaxzoom = 12;

// Every bundle's credits, shown wherever its map is: OpenStreetMap's ODbL asks for its credit with
// the data, OpenSkiMap groups runs into ski areas with Skimap.org's records, and Mapterhorn's
// terrain mixes open sources that ask the same.
export const credits = ["© OpenStreetMap contributors", "OpenSkiMap", "Skimap.org", "Protomaps", "Mapterhorn"];
