import 'package:flutter_test/flutter_test.dart';

/// Pumps until [finder] finds something. Fetches run in another isolate, which only progresses
/// in real time.
Future<void> pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var tries = 0; tries < 100 && finder.evaluate().isEmpty; tries++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
}
