import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:skimapper/map/local_map_style.dart';

void main() {
  test('the only URL in the style is the local PMTiles file', () {
    final style = jsonDecode(
      localMapStyle(basemapFile: '/data/fixture.pmtiles'),
    );

    expect(urlsIn(style), ['pmtiles://file:///data/fixture.pmtiles']);
  });
}

List<String> urlsIn(Object? node) => switch (node) {
  String value when value.contains('://') => [value],
  Map<String, Object?> map => map.values.expand(urlsIn).toList(),
  List<Object?> list => list.expand(urlsIn).toList(),
  _ => const [],
};
