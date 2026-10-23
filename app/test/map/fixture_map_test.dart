import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skimapper/map/fixture_map.dart';

import 'fake_native_map.dart';

void main() {
  testWidgets(
    'removing the map before its native view exists raises no error',
    (tester) async {
      final nativeMap = FakeNativeMap(tester, holdViewCreation: true);
      await tester.pumpWidget(_fixtureMap());
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
      final nativeMap = FakeNativeMap(tester);
      await tester.pumpWidget(_fixtureMap());
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

Widget _fixtureMap() => Directionality(
  textDirection: TextDirection.ltr,
  child: FixtureMap(
    basemapFile: '/data/fixture.pmtiles',
    onFixtureChecked: (_) {},
  ),
);
