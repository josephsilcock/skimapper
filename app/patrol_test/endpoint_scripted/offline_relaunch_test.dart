import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:skimapper/main.dart';

import '../support/endpoint_requests.dart';
import '../support/saved_catalogue.dart';

// A relaunch pair: the second test continues the first. The numbers keep that order on iOS,
// whose runner sorts tests by name.
void main() {
  patrolTest(
    'relaunch 1 of 2: loads the resort list while the endpoint serves',
    ($) async {
      // Preconditions: nothing saved; the endpoint serves the curated catalogue (group start).
      await clearSavedCatalogue();

      await $.pumpWidget(const SkimapperApp());

      await $('Espace San Bernardo')
          .waitUntilVisible(timeout: const Duration(seconds: 10));
      await awaitSavedCatalogue();
    },
  );

  patrolTest('relaunch 2 of 2: with no service, still shows the saved list', (
    $,
  ) async {
    // Preconditions: the previous test saved the curated catalogue; the endpoint is stopped here.
    await requestEndpointStopped();

    await $.pumpWidget(const SkimapperApp());

    await $('Espace San Bernardo')
        .waitUntilVisible(timeout: const Duration(seconds: 10));
    expect($('Paradiski'), findsOneWidget);
    expect($('France · Italy'), findsOneWidget);
    expect($("Couldn't refresh"), findsNothing);
  });
}
