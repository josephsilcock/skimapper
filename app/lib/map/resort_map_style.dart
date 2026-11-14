import 'dart:convert';

import 'resort_manifest.dart';

const runLineLayerId = 'run-line';

/// The only style builder: a resort's map, every path in it a local file.
String resortMapStyle({required Map<PartRole, String> parts}) => jsonEncode({
  'version': 8,
  'sources': {
    'pistes': {'type': 'geojson', 'data': 'file://${parts[PartRole.pistes]}'},
  },
  'layers': [
    {
      'id': 'background',
      'type': 'background',
      'paint': {'background-color': '#f2f2f0'},
    },
    {
      'id': runLineLayerId,
      'type': 'line',
      'source': 'pistes',
      'filter': [
        '==',
        ['get', 'kind'],
        'run',
      ],
      'paint': {'line-color': '#0060a8', 'line-width': 3},
    },
  ],
});
