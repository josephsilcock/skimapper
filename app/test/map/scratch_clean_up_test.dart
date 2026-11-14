import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skimapper/map/resort_map_providers.dart';
import 'package:skimapper/map/scratch_clean_up.dart';

void main() {
  testWidgets('the app clears what earlier launches left of resort maps', (
    tester,
  ) async {
    final root = Directory.systemTemp.createTempSync('resort-maps-');
    addTearDown(() => root.deleteSync(recursive: true));
    Directory('${root.path}/open-earlier').createSync();

    // In real time: the clean-up is file work, which a widget test's fake clock doesn't move.
    await tester.runAsync(() async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            scratchRootProvider.overrideWithValue(Future.value(root)),
          ],
          child: const ScratchCleanUp(child: SizedBox()),
        ),
      );
      for (var tries = 0; tries < 50 && root.listSync().isNotEmpty; tries++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });

    expect(root.listSync(), isEmpty);
  });
}
