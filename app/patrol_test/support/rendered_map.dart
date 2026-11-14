import 'dart:convert';
import 'dart:io';
import 'dart:math';
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

/// The fixture resort's bounds (endpoint/fixtures/resort-bundle/manifest.json).
const fixtureBounds = (west: 6.815, south: 45.573, east: 6.823, north: 45.581);

/// Expects the whole of [bounds] in view, filling at least half the view's width or height, once
/// the camera has settled (within 10 s).
Future<void> expectFramedOn(
  PatrolIntegrationTester $,
  ({double west, double south, double east, double north}) bounds,
) async {
  final controller = await resortMapController($);
  final deadline = DateTime.now().add(const Duration(seconds: 10));
  while (true) {
    final visible = await controller.getVisibleRegion();
    final failure = _framingFailure(visible, bounds);
    if (failure == null) return;
    if (DateTime.now().isAfter(deadline)) fail(failure);
    await $.pump(const Duration(milliseconds: 250));
  }
}

String? _framingFailure(
  LatLngBounds visible,
  ({double west, double south, double east, double north}) bounds,
) {
  final inView =
      visible.southwest.longitude <= bounds.west &&
      visible.southwest.latitude <= bounds.south &&
      visible.northeast.longitude >= bounds.east &&
      visible.northeast.latitude >= bounds.north;
  if (!inView) return 'the resort $bounds is not all in view $visible';
  final widthShare =
      (bounds.east - bounds.west) /
      (visible.northeast.longitude - visible.southwest.longitude);
  final heightShare =
      (bounds.north - bounds.south) /
      (visible.northeast.latitude - visible.southwest.latitude);
  final share = max(widthShare, heightShare);
  return share >= 0.5 ? null : 'the resort fills only $share of the view';
}
