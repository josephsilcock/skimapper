import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:skimapper/map/basemap_layers.dart';
import 'package:skimapper/map/resort_manifest.dart';
import 'package:skimapper/map/resort_map_style.dart';

void main() {
  test('runs are drawn from the local pistes file', () {
    expect((_style()['sources'] as Map)['pistes'], {
      'type': 'geojson',
      'data': 'file:///data/pistes.geojson',
    });
  });

  test('each run style draws its runs as lines in its colour, chosen by difficulty', () {
    const known = [
      'novice',
      'easy',
      'intermediate',
      'advanced',
      'expert',
      'freeride',
      'extreme',
    ];
    final byDifficulty = {
      RunStyle.novice: ('#1f9a2b', ['novice']),
      RunStyle.easy: ('#0060a8', ['easy']),
      RunStyle.intermediate: ('#ef2b31', ['intermediate']),
      RunStyle.advanced: ('#111111', ['advanced', 'expert']),
      RunStyle.freeride: ('#2e2a3a', ['freeride', 'extreme']),
    };
    for (final MapEntry(key: style, value: (colour, difficulties))
        in byDifficulty.entries) {
      final layer = _layer(runLayerId(style));
      expect(layer['type'], 'line', reason: '$style');
      expect((layer['paint'] as Map)['line-color'], colour, reason: '$style');
      expect(
        layer['filter'],
        contains(
          equals([
            'in',
            ['get', 'difficulty'],
            ['literal', difficulties],
          ]),
        ),
        reason: '$style',
      );
    }
    final unrated = _layer(runLayerId(RunStyle.unrated));
    expect((unrated['paint'] as Map)['line-color'], '#8a8a8a');
    expect(
      unrated['filter'],
      contains(
        equals([
          '!',
          [
            'in',
            ['get', 'difficulty'],
            ['literal', known],
          ],
        ]),
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

  test('freeride and extreme runs are dashed, and no other run is', () {
    for (final style in RunStyle.values) {
      expect(
        (_layer(runLayerId(style))['paint'] as Map).containsKey(
          'line-dasharray',
        ),
        style == RunStyle.freeride,
        reason: '$style',
      );
    }
  });

  test('run areas are a faint fill in their difficulty colour, under the run lines', () {
    final area = _layer(runAreaLayerId);
    expect(area['type'], 'fill');
    expect(
      area['filter'],
      contains(
        equals([
          '==',
          ['geometry-type'],
          'Polygon',
        ]),
      ),
    );
    final paint = area['paint'] as Map;
    expect(paint['fill-opacity'], lessThanOrEqualTo(0.25));
    expect(
      paint['fill-color'],
      containsAllInOrder([
        'match',
        ['get', 'difficulty'],
        ['novice'],
        '#1f9a2b',
        ['easy'],
        '#0060a8',
      ]),
    );
    expect(
      _layerIds(_style()),
      containsAllInOrder([runAreaLayerId, runLayerId(RunStyle.novice)]),
    );
  });

  test('lifts are a dark core in a white casing, drag lifts dotted, chosen by lift type', () {
    const dragTypes = [
      'drag_lift',
      't-bar',
      'j-bar',
      'platter',
      'rope_tow',
      'magic_carpet',
    ];
    final isDrag = [
      'in',
      ['get', 'liftType'],
      ['literal', dragTypes],
    ];
    final drag = _layer(liftLayerId(LiftStyle.drag));
    final aerial = _layer(liftLayerId(LiftStyle.aerial));
    expect(drag['filter'], contains(equals(isDrag)));
    expect(aerial['filter'], contains(equals(['!', isDrag])));
    expect((drag['paint'] as Map)['line-dasharray'], isNotNull);
    expect((aerial['paint'] as Map).containsKey('line-dasharray'), isFalse);
    expect((aerial['paint'] as Map)['line-color'], '#2e2a3a');
    final casing = _layer(liftCasingLayerId);
    expect((casing['paint'] as Map)['line-color'], '#ffffff');
    expect(
      _layerIds(_style()),
      containsAllInOrder([
        runLayerId(RunStyle.unrated),
        liftCasingLayerId,
        liftLayerId(LiftStyle.aerial),
      ]),
    );
  });

  test('aerial lifts show their stations as dots', () {
    final stations = _layer(liftStationLayerId);
    expect(stations['type'], 'circle');
    expect(stations['filter'], _layer(liftLayerId(LiftStyle.aerial))['filter']);
  });

  test('station dots show only from zoom 14, where they no longer crowd a framed resort', () {
    expect(_layer(liftStationLayerId)['minzoom'], 14);
  });

  test('named lifts are labelled along their line', () {
    final label = _layer(liftLabelLayerId);
    expect(label['type'], 'symbol');
    expect(label['filter'], _layer(liftCasingLayerId)['filter']);
    expect(label['layout'], containsPair('text-field', ['get', 'name']));
    expect(label['layout'], containsPair('symbol-placement', 'line'));
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

Map<String, Object?> _layer(String id) =>
    (_style()['layers'] as List).cast<Map<String, Object?>>().singleWhere(
      (layer) => layer['id'] == id,
      orElse: () => fail('no layer $id'),
    );

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
