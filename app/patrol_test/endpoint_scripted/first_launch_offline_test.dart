import 'package:patrol/patrol.dart';
import 'package:skimapper/main.dart';

import '../support/endpoint_requests.dart';
import '../support/saved_catalogue.dart';

void main() {
  patrolTest(
    'a first launch with no signal says the resorts could not be loaded, and Retry loads them once the service is back',
    ($) async {
      // Preconditions: nothing saved; the endpoint is stopped.
      await clearSavedCatalogue();
      await requestEndpointStopped();
      await $.pumpWidget(const SkimapperApp());

      await $("Couldn't load resorts")
          .waitUntilVisible(timeout: const Duration(seconds: 10));

      await requestCuratedCatalogue();
      await $('Retry').tap();

      await $('Espace San Bernardo')
          .waitUntilVisible(timeout: const Duration(seconds: 10));
    },
  );
}
