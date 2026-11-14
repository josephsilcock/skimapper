// Where the build reads each source. The Protomaps build is pinned: its tile schema is the one
// the app's committed basemap layers assume (app/assets/map/basemap-layers.json).
export const protomapsBuild = "https://build.protomaps.com/20261113.pmtiles";
export const mapterhornPlanet = "https://download.mapterhorn.com/planet.pmtiles";

// Mapterhorn's planet archive stops at zoom 12.
export const terrainMaxzoom = 12;
