import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:skimapper/map/resort_map.dart';

import '../support/default_resort.dart';
import '../support/endpoint_requests.dart';
import '../support/saved_catalogue.dart';

void main() {
  patrolTest(
    "with the service down, the default resort still opens at launch, says its map couldn't be loaded, and Back shows the saved list",
    ($) async {
      // Preconditions: the curated catalogue saved; Paradiski is the default resort; the endpoint
      // is stopped.
      await clearSavedCatalogue();
      await requestCuratedCatalogue();
      await saveCatalogueCopy(await servedCatalogue());
      await setDefaultResort('paradiski');
      await requestEndpointStopped();

      expect(await launchApp($), endsWith('launch: reopens paradiski'));

      await $(AppBar).$('Paradiski').waitUntilVisible();
      await $("Couldn't load map")
          .waitUntilVisible(timeout: const Duration(seconds: 15));
      expect($('Retry'), findsOneWidget);
      expect($(ResortMap), findsNothing);

      await $(BackButton).tap();

      await $('Espace San Bernardo')
          .waitUntilVisible(timeout: const Duration(seconds: 10));
      expect(await readDefaultResort(), 'paradiski');
    },
  );
}
