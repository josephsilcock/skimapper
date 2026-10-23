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
      final nativeMap = FakeNativeMap(tester, holdWaitForMap: true);
      await tester.pumpWidget(_fixtureMap());
      await tester.pump();
      expect(nativeMap.waitForMapRequested, isTrue);

      await tester.pumpWidget(const SizedBox());

      expect(await nativeMap.sendToMap('map#onStyleLoaded'), isFalse);
    },
    variant: _bothTargets,
  );

  testWidgets(
    'removing the map while a fixture query is in flight reports nothing',
    (tester) async {
      final nativeMap = FakeNativeMap(tester);
      final reports = await _pumpMapWithStyleLoaded(tester, nativeMap);
      expect(nativeMap.queryInFlight, isTrue);

      await tester.pumpWidget(const SizedBox());
      nativeMap.answerQuery(found: true);
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(reports, isEmpty);
    },
  );

  testWidgets(
    'removing the map between fixture queries stops the check and reports nothing',
    (tester) async {
      final nativeMap = FakeNativeMap(tester);
      final reports = await _pumpMapWithStyleLoaded(tester, nativeMap);
      nativeMap.answerQuery(found: false);
      await tester.pump();

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 11));

      expect(tester.takeException(), isNull);
      expect(reports, isEmpty);
    },
  );

  testWidgets('a map whose fixture never renders reports so at the deadline', (
    tester,
  ) async {
    final nativeMap = FakeNativeMap(tester, fixtureNeverRenders: true);
    final reports = await _pumpMapWithStyleLoaded(tester, nativeMap);

    await tester.pump(const Duration(seconds: 11));

    expect(reports, [false]);
  });
}

final _bothTargets = TargetPlatformVariant({
  TargetPlatform.android,
  TargetPlatform.iOS,
});

Widget _fixtureMap({ValueChanged<bool>? onFixtureChecked}) => Directionality(
  textDirection: TextDirection.ltr,
  child: FixtureMap(
    basemapFile: '/data/fixture.pmtiles',
    onFixtureChecked: onFixtureChecked ?? (_) {},
  ),
);

/// Pumps the map through to its style loading, and returns the fixture-check reports it makes.
Future<List<bool>> _pumpMapWithStyleLoaded(
  WidgetTester tester,
  FakeNativeMap nativeMap,
) async {
  final reports = <bool>[];
  await tester.pumpWidget(_fixtureMap(onFixtureChecked: reports.add));
  await tester.pump();
  await nativeMap.sendToMap('map#onStyleLoaded');
  await tester.pump();
  return reports;
}
