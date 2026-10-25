import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:skimapper/main.dart';

import '../support/list_order.dart';
import '../support/saved_catalogue.dart';

void main() {
  patrolTest(
    'lists the curated ski areas sorted by name, each with its countries',
    ($) async {
      await clearSavedCatalogue();
      await $.pumpWidget(const SkimapperApp());

      await $('Espace San Bernardo')
          .waitUntilVisible(timeout: const Duration(seconds: 10));
      expectTopToBottom($, [
        'Espace San Bernardo',
        'Les 3 Vallées',
        'Paradiski',
      ]);
      expect($('France · Italy'), findsOneWidget);
    },
  );
}
