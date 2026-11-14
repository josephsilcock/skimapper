import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:skimapper/map/basemap_layers.dart';

void main() {
  final layers = BasemapLayers.fromJson(
    File(basemapLayersAsset).readAsStringSync(),
  );
  final all = [...layers.under, ...layers.over].cast<Map<String, Object?>>();

  test('the background draws no icons and no points of interest but peaks', () {
    for (final layer in all) {
      expect(
        (layer['layout'] as Map?)?.containsKey('icon-image') ?? false,
        isFalse,
        reason: '${layer['id']}',
      );
    }
    expect(
      all
          .where((layer) => layer['source-layer'] == 'pois')
          .map((layer) => layer['id']),
      ['peak_label'],
    );
  });

  test('peaks are labelled in grey', () {
    final peaks = all.singleWhere((layer) => layer['id'] == 'peak_label');
    expect(peaks['filter'], [
      '==',
      ['get', 'kind'],
      'peak',
    ]);
    expect((peaks['paint'] as Map)['text-color'], '#7a7a7a');
  });
}
