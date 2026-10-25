import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skimapper/attribution/attribution_line.dart';
import 'package:skimapper/main.dart';

import 'map/fake_native_map.dart';

void main() {
  testWidgets('a snackbar on the home screen leaves the credits uncovered', (
    tester,
  ) async {
    FakeNativeMap(tester);
    await tester.pumpWidget(const SkimapperApp());

    ScaffoldMessenger.of(tester.element(find.byType(AttributionLine)))
        .showSnackBar(const SnackBar(content: Text('a message')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    final snackBar = tester.getRect(
      find.descendant(
        of: find.byType(SnackBar),
        matching: find.byType(Material),
      ),
    );
    final credits = tester.getRect(find.byType(AttributionLine));
    expect(snackBar.overlaps(credits), isFalse);
  });
}
