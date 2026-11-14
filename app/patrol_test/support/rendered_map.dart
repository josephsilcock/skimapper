import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:patrol/patrol.dart';
import 'package:skimapper/map/resort_map.dart';

/// The open resort map's controller, once the map exists.
Future<MapLibreMapController> resortMapController(
  PatrolIntegrationTester $,
) async {
  await $(ResortMap).waitUntilExists(timeout: const Duration(seconds: 30));
  final deadline = DateTime.now().add(const Duration(seconds: 30));
  while (true) {
    final controller = $.tester
        .state<ResortMapState>(find.byType(ResortMap))
        .controller;
    if (controller != null) return controller;
    if (DateTime.now().isAfter(deadline)) fail('the map was never created');
    await $.pump(const Duration(milliseconds: 250));
  }
}

/// The names of the features drawn in [layerIds] anywhere in view, once any are drawn.
Future<Set<String?>> renderedNames(
  PatrolIntegrationTester $,
  List<String> layerIds,
) async {
  final controller = await resortMapController($);
  final deadline = DateTime.now().add(const Duration(seconds: 30));
  while (true) {
    final rendered = await controller.queryRenderedFeaturesInRect(
      _wholeMap($),
      layerIds,
      null,
    );
    if (rendered.isNotEmpty) return rendered.map(_name).toSet();
    if (DateTime.now().isAfter(deadline)) {
      fail('nothing was drawn in $layerIds within 30 s');
    }
    await $.pump(const Duration(milliseconds: 250));
  }
}

/// The map's whole area, in Android pixels or iOS points: a rect beyond the map finds nothing on
/// iOS.
Rect _wholeMap(PatrolIntegrationTester $) {
  final size = $.tester.getSize(find.byType(ResortMap));
  final scale = Platform.isAndroid ? $.tester.view.devicePixelRatio : 1.0;
  return Offset.zero & size * scale;
}

String? _name(Object? feature) => switch (feature) {
  String json => _name(jsonDecode(json)),
  {'properties': {'name': final String? name}} => name,
  _ => null,
};
