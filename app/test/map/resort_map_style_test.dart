import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:skimapper/map/resort_manifest.dart';
import 'package:skimapper/map/resort_map_style.dart';

void main() {
  test('runs are drawn as lines from the local pistes file', () {
    final style = _style();

    expect(style['sources'], {
      'pistes': {'type': 'geojson', 'data': 'file:///data/pistes.geojson'},
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

  test('every URL in the style is a local file', () {
    expect(_urlsIn(_style()), everyElement(startsWith('file://')));
  });
}

List<String> _urlsIn(Object? node) => switch (node) {
  String value when value.contains('://') => [value],
  Map<String, Object?> map => map.values.expand(_urlsIn).toList(),
  List<Object?> list => list.expand(_urlsIn).toList(),
  _ => const [],
};

Map<String, Object?> _style() =>
    jsonDecode(resortMapStyle(parts: {PartRole.pistes: '/data/pistes.geojson'}))
        as Map<String, Object?>;
