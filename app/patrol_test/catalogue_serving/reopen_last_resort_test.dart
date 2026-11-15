import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import '../support/default_resort.dart';
import '../support/saved_catalogue.dart';

// A relaunch chain: each step continues the one before. The numbers keep that order on iOS,
// whose runner sorts tests by name.
void main() {
  patrolTest(
    'reopen 1 of 3: opening Paradiski from the list makes it the default resort',
    ($) async {
      // Preconditions: nothing saved; no default resort.
      await clearSavedCatalogue();
      await clearDefaultResort();
      expect(await launchApp($), endsWith('launch: shows the list'));

      await $('Paradiski')
          .waitUntilVisible(timeout: const Duration(seconds: 10));
      await $('Paradiski').tap();

      await $(AppBar).$('Paradiski').waitUntilVisible();
      await awaitSavedCatalogue();
      await awaitDefaultResort('paradiski');
    },
  );

  patrolTest(
    "reopen 2 of 3: a relaunch opens Paradiski's map straight away, and Back shows the list",
    ($) async {
      // Preconditions: the previous step saved the catalogue and made Paradiski the default.
      expect(await launchApp($), endsWith('launch: reopens paradiski'));

      await $(AppBar).$('Paradiski').waitUntilVisible();
      await $(BackButton).tap();

      await $('Espace San Bernardo')
          .waitUntilVisible(timeout: const Duration(seconds: 10));
      expect($(AppBar), findsNothing);
    },
  );

  patrolTest(
    "reopen 3 of 3: after Back, a relaunch still opens Paradiski's map",
    ($) async {
      // Preconditions: the previous step went back to the list, leaving the default as it was.
      expect(await launchApp($), endsWith('launch: reopens paradiski'));

      await $(AppBar).$('Paradiski').waitUntilVisible();
    },
  );
}
