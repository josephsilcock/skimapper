import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:skimapper/map/basemap_layers.dart';
import 'package:skimapper/map/resort_manifest.dart';
import 'package:skimapper/map/resort_map_style.dart';

void main() {
  test('runs are drawn as lines from the local pistes file', () {
    final style = _style();

    expect((style['sources'] as Map)['pistes'], {
      'type': 'geojson',
      'data': 'file:///data/pistes.geojson',
    });
    expect(
      (style['layers'] as List).where((layer) => layer['source'] == 'pistes'),
      contains(
        allOf(
          containsPair('type', 'line'),
          containsPair('filter', [
            '==',
            ['get', 'kind'],
            'run',
          ]),
        ),
      ),
    );
  });

  test('the basemap is drawn with its layers from the local basemap file', () {
    final style = _style();

    expect((style['sources'] as Map)['basemap'], {
      'type': 'vector',
      'url': 'pmtiles://file:///data/basemap.pmtiles',
    });
    expect(_layerIds(style), containsAllInOrder(['earth', 'roads_minor']));
  });

  test(
    'the terrain shades the map over land cover and under roads and labels',
    () {
      final style = _style();

      expect((style['sources'] as Map)['terrain'], {
        'type': 'raster-dem',
        'url': 'pmtiles://file:///data/terrain.pmtiles',
        'encoding': 'terrarium',
        'tileSize': 512,
      });
      expect(
        _layerIds(style),
        containsAllInOrder(['earth', hillshadeLayerId, 'roads_minor']),
      );
    },
  );

  test('named runs are labelled along their line, with glyphs from the local glyphs folder', () {
    final style = _style();

    expect(style['glyphs'], 'file:///data/glyphs/{fontstack}/{range}.pbf');
    expect(
      style['layers'],
      contains(
        allOf(
          containsPair('id', runLabelLayerId),
          containsPair('type', 'symbol'),
          containsPair('source', 'pistes'),
          containsPair(
            'layout',
            allOf(
              containsPair('text-field', ['get', 'name']),
              containsPair('symbol-placement', 'line'),
            ),
          ),
        ),
      ),
    );
  });

  test('every URL in the style is a local file', () {
    expect(_urlsIn(_style()), everyElement(matches(r'^(pmtiles://)?file://')));
  });
}

List<String> _urlsIn(Object? node) => switch (node) {
  String value when value.contains('://') => [value],
  Map<String, Object?> map => map.values.expand(_urlsIn).toList(),
  List<Object?> list => list.expand(_urlsIn).toList(),
  _ => const [],
};

List<Object?> _layerIds(Map<String, Object?> style) => [
  for (final layer in style['layers'] as List) (layer as Map)['id'],
];

Map<String, Object?> _style() => jsonDecode(
  resortMapStyle(
    parts: {
      PartRole.pistes: '/data/pistes.geojson',
      PartRole.basemap: '/data/basemap.pmtiles',
      PartRole.terrain: '/data/terrain.pmtiles',
    },
    glyphs: '/data/glyphs',
    basemap: _basemap,
  ),
) as Map<String, Object?>;

const _basemap = BasemapLayers(
  under: [
    {
      'id': 'earth',
      'type': 'fill',
      'source': 'basemap',
      'source-layer': 'earth',
    },
  ],
  over: [
    {
      'id': 'roads_minor',
      'type': 'line',
      'source': 'basemap',
      'source-layer': 'roads',
    },
  ],
);
