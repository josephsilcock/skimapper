import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:skimapper/map/basemap_layers.dart';
import 'package:skimapper/map/map_assets.dart';
import 'package:skimapper/map/resort_manifest.dart';
import 'package:skimapper/map/resort_map.dart';
import 'package:skimapper/map/resort_map_style.dart';

import 'fake_native_map.dart';

void main() {
  testWidgets(
    'draws the resort with the style of its local parts, glyphs and basemap',
    (tester) async {
      FakeNativeMap(tester);
      await tester.pumpWidget(_resortMap());

      expect(
        tester.widget<MapLibreMap>(find.byType(MapLibreMap)).styleString,
        resortMapStyle(
          parts: _parts,
          glyphs: _assets.glyphs,
          basemap: _assets.basemap,
        ),
      );
    },
  );

  testWidgets('frames the camera on the whole resort once its style loads', (
    tester,
  ) async {
    final nativeMap = FakeNativeMap(tester);
    await tester.pumpWidget(_resortMap());
    await tester.pump();

    await nativeMap.sendToMap('map#onStyleLoaded');
    await tester.pump();

    expect(nativeMap.cameraMoves, [
      [
        'newLatLngBounds',
        [
          [closeTo(45.57, 1e-9), closeTo(6.81, 1e-9)],
          [closeTo(45.585, 1e-9), closeTo(6.83, 1e-9)],
        ],
        32.0,
        32.0,
        32.0,
        32.0,
      ],
    ]);
  });

  testWidgets(
    'once its style loads, the map only frames the camera: it adds no layers that leaving it could interrupt',
    (tester) async {
      final nativeMap = FakeNativeMap(tester);
      await tester.pumpWidget(_resortMap());
      await tester.pump();
      final callsBeforeStyle = nativeMap.mapCalls.length;

      await nativeMap.sendToMap('map#onStyleLoaded');
      await tester.pump();

      expect(nativeMap.mapCalls.skip(callsBeforeStyle), ['camera#move']);
    },
  );

  testWidgets(
    'the map pans, zooms and rotates with a compass, never tilts, and ignores taps',
    (tester) async {
      FakeNativeMap(tester);
      await tester.pumpWidget(_resortMap());

      final map = tester.widget<MapLibreMap>(find.byType(MapLibreMap));
      expect(map.scrollGesturesEnabled, isTrue);
      expect(map.zoomGesturesEnabled, isTrue);
      expect(map.rotateGesturesEnabled, isTrue);
      expect(map.compassEnabled, isTrue);
      expect(map.tiltGesturesEnabled, isFalse);
      expect(map.onMapClick, isNull);
      expect(map.onMapLongClick, isNull);
      expect(map.logoEnabled, isFalse);
    },
  );

  testWidgets(
    "MapLibre's own attribution button sits off the map: the credits bar credits it",
    (tester) async {
      FakeNativeMap(tester);
      await tester.pumpWidget(_resortMap());

      final margins = tester
          .widget<MapLibreMap>(find.byType(MapLibreMap))
          .attributionButtonMargins;
      expect(margins, isNotNull);
      expect(margins!.x, lessThanOrEqualTo(-100));
      expect(margins.y, lessThanOrEqualTo(-100));
    },
  );

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

const _parts = {
  PartRole.pistes: '/data/pistes.geojson',
  PartRole.basemap: '/data/basemap.pmtiles',
  PartRole.terrain: '/data/terrain.pmtiles',
};

const _assets = MapAssets(
  glyphs: '/data/glyphs',
  basemap: BasemapLayers(
    under: [
      {
        'id': 'earth',
        'type': 'fill',
        'source': 'basemap',
        'source-layer': 'earth',
      },
    ],
    over: [],
  ),
);

Widget _resortMap() => const Directionality(
  textDirection: TextDirection.ltr,
  child: ResortMap(
    manifest: ResortManifest(
      bounds: (west: 6.81, south: 45.57, east: 6.83, north: 45.585),
      credits: [],
      parts: [],
    ),
    parts: _parts,
    assets: _assets,
  ),
);
