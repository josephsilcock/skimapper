import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import '../support/default_resort.dart';
import '../support/endpoint_requests.dart';
import '../support/saved_catalogue.dart';

void main() {
  patrolTest(
    'with a saved list that cannot be read, launch shows the list as with nothing saved, and the default stays',
    ($) async {
      // Preconditions: a corrupt saved catalogue; Paradiski is the default resort; the endpoint
      // serves the curated catalogue.
      await saveCatalogueCopy('not a catalogue');
      await setDefaultResort('paradiski');
      await requestCuratedCatalogue();

      expect(await launchApp($), endsWith('launch: shows the list'));

      await $('Espace San Bernardo')
          .waitUntilVisible(timeout: const Duration(seconds: 10));
      expect(await readDefaultResort(), 'paradiski');
    },
  );
}
