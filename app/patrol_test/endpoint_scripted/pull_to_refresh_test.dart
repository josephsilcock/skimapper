import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:skimapper/main.dart';

import '../support/endpoint_requests.dart';
import '../support/list_order.dart';
import '../support/saved_catalogue.dart';

void main() {
  patrolTest(
    'pulling the list down shows a ski area the catalogue has since gained, in its sorted place',
    ($) async {
      // Preconditions: nothing saved; the endpoint serves the curated catalogue.
      await clearSavedCatalogue();
      await requestCuratedCatalogue();
      await $.pumpWidget(const SkimapperApp());
      await $('Espace San Bernardo')
          .waitUntilVisible(timeout: const Duration(seconds: 10));

      await requestCatalogueWithExtraArea();
      await $.tester.fling(find.text('Paradiski'), const Offset(0, 400), 1000);

      await $(extraArea).waitUntilVisible(timeout: const Duration(seconds: 10));
      expectTopToBottom($, [
        'Espace San Bernardo',
        extraArea,
        'Les 3 Vallées',
        'Paradiski',
      ]);
    },
  );
}
