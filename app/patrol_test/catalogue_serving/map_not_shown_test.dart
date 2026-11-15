import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:skimapper/main.dart';
import 'package:skimapper/map/resort_map.dart';

import '../support/default_resort.dart';
import '../support/saved_catalogue.dart';

// tools/e2e seeds Les 3 Vallées with a part that doesn't match its hash, and Espace San Bernardo
// with a manifest at a schema version no app knows (endpoint/scripts/build/seeded-bundles.ts).
void main() {
  patrolTest(
    "a part that doesn't match its manifest's hash isn't shown: the map couldn't be loaded",
    ($) async {
      await clearSavedCatalogue();
      await clearDefaultResort();
      await $.pumpWidget(const SkimapperApp());
      await $('Les 3 Vallées')
          .waitUntilVisible(timeout: const Duration(seconds: 10));

      await $('Les 3 Vallées').tap();

      await $("Couldn't load map")
          .waitUntilVisible(timeout: const Duration(seconds: 15));
      await $('Retry').waitUntilVisible();
      expect($(ResortMap), findsNothing);
    },
  );

  patrolTest(
    'a map this app version cannot read asks for an app update, with Retry',
    ($) async {
      await clearSavedCatalogue();
      await clearDefaultResort();
      await $.pumpWidget(const SkimapperApp());
      await $('Espace San Bernardo')
          .waitUntilVisible(timeout: const Duration(seconds: 10));

      await $('Espace San Bernardo').tap();

      await $(AppBar).$('Espace San Bernardo').waitUntilVisible();
      await $('Update SkiMapper to see this map')
          .waitUntilVisible(timeout: const Duration(seconds: 15));
      await $('Retry').waitUntilVisible();
      expect($(ResortMap), findsNothing);
    },
  );
}
