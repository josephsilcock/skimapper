import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

/// Expects [names] on screen top to bottom in exactly this order.
void expectTopToBottom(PatrolIntegrationTester $, List<String> names) {
  final tops = {
    for (final name in names) name: $.tester.getTopLeft(find.text(name)).dy,
  };
  final shown = [...names]..sort((a, b) => tops[a]!.compareTo(tops[b]!));
  expect(shown, names, reason: 'top to bottom');
}
