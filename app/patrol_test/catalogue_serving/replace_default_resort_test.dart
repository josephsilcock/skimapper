import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import '../support/default_resort.dart';
import '../support/saved_catalogue.dart';

// A relaunch chain: the second step continues the first. The numbers keep that order on iOS,
// whose runner sorts tests by name.
void main() {
  patrolTest(
    'replace 1 of 2: opening Espace San Bernardo over a Paradiski default makes it the default',
    ($) async {
      // Preconditions: nothing saved; Paradiski is the default resort.
      await clearSavedCatalogue();
      await setDefaultResort('paradiski');
      await launchApp($);

      await $('Espace San Bernardo')
          .waitUntilVisible(timeout: const Duration(seconds: 10));
      await $('Espace San Bernardo').tap();

      await $(AppBar).$('Espace San Bernardo').waitUntilVisible();
      await awaitSavedCatalogue();
      await awaitDefaultResort('espace-san-bernardo');
    },
  );

  patrolTest("replace 2 of 2: a relaunch opens Espace San Bernardo's map", (
    $,
  ) async {
    // Preconditions: the previous step saved the catalogue and made Espace San Bernardo the
    // default.
    expect(await launchApp($), endsWith('launch: reopens espace-san-bernardo'));

    await $(AppBar).$('Espace San Bernardo').waitUntilVisible();
  });
}
