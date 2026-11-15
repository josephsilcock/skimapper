import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import '../support/default_resort.dart';
import '../support/endpoint_requests.dart';
import '../support/saved_catalogue.dart';

// A relaunch chain: each step continues the one before. The numbers keep that order on iOS,
// whose runner sorts tests by name.
void main() {
  patrolTest(
    'not listed 1 of 3: a default resort the saved list lacks shows the list, and stays the default',
    ($) async {
      // Preconditions: nothing saved; the default resort is the extra area, which the curated
      // catalogue the endpoint serves lacks.
      await clearSavedCatalogue();
      await setDefaultResort('extra-area');
      await requestCuratedCatalogue();

      expect(await launchApp($), endsWith('launch: shows the list'));

      await $('Espace San Bernardo')
          .waitUntilVisible(timeout: const Duration(seconds: 10));
      await awaitSavedCatalogue();
      expect(find.byType(SnackBar), findsNothing);
      expect(find.byType(MaterialBanner), findsNothing);
      expect(await readDefaultResort(), 'extra-area');
    },
  );

  patrolTest(
    'not listed 2 of 3: still not in the list saved at launch, the list shows while the extra area is saved',
    ($) async {
      // Preconditions: the curated catalogue is saved; the endpoint now serves the extra area too.
      await requestCatalogueWithExtraArea();

      expect(await launchApp($), endsWith('launch: shows the list'));

      await $(extraArea).waitUntilVisible(timeout: const Duration(seconds: 10));
      await awaitSavedCatalogueListing(extraArea);
      expect(await readDefaultResort(), 'extra-area');
    },
  );

  patrolTest(
    "not listed 3 of 3: once the saved list has the default resort, a relaunch opens its map",
    ($) async {
      // Preconditions: the saved catalogue lists the extra area, still the default resort.
      expect(await launchApp($), endsWith('launch: reopens extra-area'));

      await $(AppBar).$(extraArea).waitUntilVisible();
    },
  );
}
