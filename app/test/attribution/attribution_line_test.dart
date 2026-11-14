import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skimapper/attribution/attribution_line.dart';

void main() {
  testWidgets('credits each source it is given, in order', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AttributionLine(
          credits: ['© OpenStreetMap contributors', 'Mapterhorn'],
        ),
      ),
    );

    expect(
      find.text('© OpenStreetMap contributors · Mapterhorn'),
      findsOneWidget,
    );
  });
}
