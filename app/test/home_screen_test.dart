import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skimapper/attribution/attribution_line.dart';
import 'package:skimapper/launch/launch_decision.dart';
import 'package:skimapper/main.dart';

import 'map/fake_native_map.dart';

void main() {
  testWidgets('the home screen is the resort list alone, with no credits', (
    tester,
  ) async {
    FakeNativeMap(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [resortToReopenProvider.overrideWith((ref) async => null)],
        child: const SkimapperApp(),
      ),
    );
    await tester.pump();

    expect(find.text('SkiMapper'), findsOneWidget);
    expect(find.byType(AttributionLine), findsNothing);
  });
}
