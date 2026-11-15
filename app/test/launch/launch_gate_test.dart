import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skimapper/launch/launch_decision.dart';
import 'package:skimapper/main.dart';
import 'package:skimapper/resorts/catalogue.dart';

import '../map/fake_native_map.dart';
import '../support/run_record_capture.dart';

void main() {
  testWidgets(
    'with a resort to reopen, the app opens on its map, and Back shows the list',
    (tester) async {
      FakeNativeMap(tester);
      await tester.pumpWidget(_appReopening(_paradiski));
      await tester.pump();

      expect(find.widgetWithText(AppBar, 'Paradiski'), findsOneWidget);

      await tester.pageBack();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('SkiMapper'), findsOneWidget);
    },
  );

  testWidgets(
    'the first frame waits for the launch decision, with nothing of the list built',
    (tester) async {
      final decision = Completer<Resort?>();
      tester.binding.resetFirstFrameSent();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            resortToReopenProvider.overrideWith((ref) => decision.future),
          ],
          child: const SkimapperApp(),
        ),
      );

      expect(tester.binding.sendFramesToEngine, isFalse);
      expect(find.text('SkiMapper'), findsNothing);

      decision.complete(null);
      await tester.pump();
      await tester.pump();

      expect(tester.binding.sendFramesToEngine, isTrue);
      expect(find.text('SkiMapper'), findsOneWidget);
    },
  );

  testWidgets('launch records the resort it reopens', (tester) async {
    FakeNativeMap(tester);

    final logged = await runRecordDuring(() async {
      await tester.pumpWidget(_appReopening(_paradiski));
      await tester.pump();
    });

    expect(logged.where((line) => line.contains('launch:')), [
      matches(appRunRecordLine('launch: reopens paradiski')),
    ]);
  });

  testWidgets(
    'launch records that it shows the list when there is nothing to reopen',
    (tester) async {
      final logged = await runRecordDuring(() async {
        await tester.pumpWidget(_appReopening(null));
        await tester.pump();
      });

      expect(logged.where((line) => line.contains('launch:')), [
        matches(appRunRecordLine('launch: shows the list')),
      ]);
    },
  );

  testWidgets(
    'a launch decision that fails shows the list, is recorded, and releases the first frame',
    (tester) async {
      tester.binding.resetFirstFrameSent();

      final logged = await runRecordDuring(() async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              resortToReopenProvider.overrideWith(
                (ref) => Future.error(const FileSystemException('unreadable')),
              ),
            ],
            child: const SkimapperApp(),
          ),
        );
        await tester.pump();
        await tester.pump();
      });

      expect(find.text('SkiMapper'), findsOneWidget);
      expect(tester.binding.sendFramesToEngine, isTrue);
      expect(logged.where((line) => line.contains('launch:')), [
        matches(
          appRunRecordLine(
            'launch: decision failed, shows the list: .*unreadable.*',
          ),
        ),
      ]);
    },
  );

  testWidgets(
    'an app gone before launch decides still releases the first frame',
    (tester) async {
      final decision = Completer<Resort?>();
      tester.binding.resetFirstFrameSent();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            resortToReopenProvider.overrideWith((ref) => decision.future),
          ],
          child: const SkimapperApp(),
        ),
      );

      await tester.pumpWidget(const SizedBox());

      expect(tester.binding.sendFramesToEngine, isTrue);

      // The decision landing afterwards releases nothing twice.
      decision.complete(null);
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
}

Widget _appReopening(Resort? resort) => ProviderScope(
  overrides: [resortToReopenProvider.overrideWith((ref) async => resort)],
  child: const SkimapperApp(),
);

const _paradiski = Resort(
  id: 'paradiski',
  name: 'Paradiski',
  countries: ['France'],
  centre: (lat: 45.55, lon: 6.8),
);
