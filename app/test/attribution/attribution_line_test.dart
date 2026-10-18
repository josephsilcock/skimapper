import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skimapper/attribution/attribution_line.dart';

void main() {
  testWidgets('credits every source the map and resort data come from', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: AttributionLine()));

    expect(
      find.text(
        '© OpenStreetMap contributors · OpenSkiMap · Protomaps · Mapterhorn',
      ),
      findsOneWidget,
    );
  });
}
