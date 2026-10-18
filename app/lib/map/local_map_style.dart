import 'dart:convert';

const fixtureLayerId = 'fixture-fill';

String localMapStyle({required String basemapFile}) => jsonEncode({
  'version': 8,
  'sources': {
    'basemap': {'type': 'vector', 'url': 'pmtiles://file://$basemapFile'},
  },
  'layers': [
    {
      'id': 'background',
      'type': 'background',
      'paint': {'background-color': '#ffffff'},
    },
    {
      'id': fixtureLayerId,
      'type': 'fill',
      'source': 'basemap',
      'source-layer': 'fixture',
      'paint': {'fill-color': '#3b82f6'},
    },
  ],
});
