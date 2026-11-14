import 'dart:convert';

import 'basemap_layers.dart';
import 'resort_manifest.dart';

const runLineLayerId = 'run-line';
const runLabelLayerId = 'run-label';
const hillshadeLayerId = 'hillshade';

/// The basemap's land layer, drawn wherever there is land.
const basemapLandLayerId = 'earth';

/// The only style builder: a resort's map, every path in it a local file.
String resortMapStyle({
  required Map<PartRole, String> parts,
  required String glyphs,
  required BasemapLayers basemap,
}) => jsonEncode({
  'version': 8,
  'glyphs': 'file://$glyphs/{fontstack}/{range}.pbf',
  'sources': {
    'basemap': {
      'type': 'vector',
      'url': 'pmtiles://file://${parts[PartRole.basemap]}',
    },
    'terrain': {
      'type': 'raster-dem',
      'url': 'pmtiles://file://${parts[PartRole.terrain]}',
      'encoding': 'terrarium',
      'tileSize': 512,
    },
    'pistes': {'type': 'geojson', 'data': 'file://${parts[PartRole.pistes]}'},
  },
  'layers': [
    {
      'id': 'background',
      'type': 'background',
      'paint': {'background-color': '#f2f2f0'},
    },
    ...basemap.under,
    {
      'id': hillshadeLayerId,
      'type': 'hillshade',
      'source': 'terrain',
      'paint': {'hillshade-exaggeration': 0.5},
    },
    ...basemap.over,
    {
      'id': runLineLayerId,
      'type': 'line',
      'source': 'pistes',
      'filter': _isRun,
      'paint': {'line-color': '#0060a8', 'line-width': 3},
    },
    {
      'id': runLabelLayerId,
      'type': 'symbol',
      'source': 'pistes',
      'filter': _isRun,
      'layout': {
        'text-field': ['get', 'name'],
        'text-font': ['Noto Sans Regular'],
        'text-size': 12,
        'symbol-placement': 'line',
      },
      'paint': {
        'text-color': '#1b2a2e',
        'text-halo-color': '#ffffff',
        'text-halo-width': 1.5,
      },
    },
  ],
});

const _isRun = [
  '==',
  ['get', 'kind'],
  'run',
];
