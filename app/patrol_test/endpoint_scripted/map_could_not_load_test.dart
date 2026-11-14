import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:skimapper/main.dart';
import 'package:skimapper/map/resort_map.dart';

import '../support/endpoint_requests.dart';
import '../support/saved_catalogue.dart';

void main() {
  patrolTest(
    "a resort opened while the service is down says its map couldn't be loaded, and Retry loads it once the service is back",
    ($) async {
      // Preconditions: nothing saved; the endpoint serves the curated catalogue, then stops.
      await clearSavedCatalogue();
      await requestCuratedCatalogue();
      await $.pumpWidget(const SkimapperApp());
      await $('Paradiski')
          .waitUntilVisible(timeout: const Duration(seconds: 10));
      await requestEndpointStopped();

      await $('Paradiski').tap();

      await $(AppBar).$('Paradiski').waitUntilVisible();
      await $("Couldn't load map")
          .waitUntilVisible(timeout: const Duration(seconds: 15));
      expect($(ResortMap), findsNothing);

      await requestCuratedCatalogue();
      await $('Retry').tap();

      await $(ResortMap).waitUntilExists(timeout: const Duration(seconds: 15));
      expect($("Couldn't load map"), findsNothing);
    },
  );
}
