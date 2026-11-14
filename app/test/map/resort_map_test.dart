import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:skimapper/map/resort_manifest.dart';
import 'package:skimapper/map/resort_map.dart';
import 'package:skimapper/map/resort_map_style.dart';

import 'fake_native_map.dart';

void main() {
  testWidgets('draws the resort with the style of its local parts', (
    tester,
  ) async {
    FakeNativeMap(tester);
    await tester.pumpWidget(_resortMap());

    expect(
      tester.widget<MapLibreMap>(find.byType(MapLibreMap)).styleString,
      resortMapStyle(parts: _parts),
    );
  });

  testWidgets(
    'removing the map before its native view exists raises no error',
    (tester) async {
      final nativeMap = FakeNativeMap(tester, holdViewCreation: true);
      await tester.pumpWidget(_resortMap());
      await tester.pump();
      expect(nativeMap.viewCreationRequested, isTrue);

      await tester.pumpWidget(const SizedBox());

      expect(tester.takeException(), isNull);
    },
    variant: _bothTargets,
  );

  testWidgets(
    'removing the map while it waits for the native map leaves no inbound handler behind',
    (tester) async {
      final nativeMap = FakeNativeMap(tester, holdWaitForMap: true);
      await tester.pumpWidget(_resortMap());
      await tester.pump();
      expect(nativeMap.waitForMapRequested, isTrue);

      await tester.pumpWidget(const SizedBox());

      expect(await nativeMap.sendToMap('map#onStyleLoaded'), isFalse);
    },
    variant: _bothTargets,
  );
}

final _bothTargets = TargetPlatformVariant({
  TargetPlatform.android,
  TargetPlatform.iOS,
});

const _parts = {PartRole.pistes: '/data/pistes.geojson'};

Widget _resortMap() => const Directionality(
  textDirection: TextDirection.ltr,
  child: ResortMap(
    manifest: ResortManifest(
      bounds: (west: 6.81, south: 45.57, east: 6.83, north: 45.585),
      credits: [],
      parts: [],
    ),
    parts: _parts,
  ),
);
