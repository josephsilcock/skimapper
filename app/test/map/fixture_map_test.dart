import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skimapper/map/fixture_map.dart';

import 'fake_native_map.dart';

void main() {
  testWidgets(
    'removing the map before its native view exists raises no error',
    (tester) async {
      final nativeMap = FakeNativeMap(tester);
      await tester.pumpWidget(_fixtureMap());
      await tester.pump();
      expect(nativeMap.viewCreationRequested, isTrue);

      await tester.pumpWidget(const SizedBox());

      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}

Widget _fixtureMap() => Directionality(
  textDirection: TextDirection.ltr,
  child: FixtureMap(
    basemapFile: '/data/fixture.pmtiles',
    onFixtureChecked: (_) {},
  ),
);
