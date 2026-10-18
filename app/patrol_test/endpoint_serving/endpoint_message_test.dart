import 'package:patrol/patrol.dart';
import 'package:skimapper/main.dart';

const _seededMessage = String.fromEnvironment('E2E_SEEDED_MESSAGE');

void main() {
  patrolTest('shows the message the endpoint serves', ($) async {
    await $.pumpWidget(const SkimapperApp());

    await $(_seededMessage)
        .waitUntilVisible(timeout: const Duration(seconds: 10));
  });
}
