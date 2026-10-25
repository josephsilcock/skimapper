import 'package:patrol/patrol.dart';
import 'package:skimapper/main.dart';

import '../support/saved_catalogue.dart';

void main() {
  patrolTest(
    'with nothing saved, a catalogue version this app does not know asks for an app update, with Retry',
    ($) async {
      // Preconditions: nothing saved; the endpoint serves the catalogue at an unknown schema version.
      await clearSavedCatalogue();
      await $.pumpWidget(const SkimapperApp());

      await $('Update SkiMapper to see resorts')
          .waitUntilVisible(timeout: const Duration(seconds: 10));
      await $('Retry').waitUntilVisible();
    },
  );
}
