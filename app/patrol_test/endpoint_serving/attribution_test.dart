import 'package:patrol/patrol.dart';
import 'package:skimapper/main.dart';

import '../support/saved_catalogue.dart';

void main() {
  patrolTest('credits the map and resort data sources', ($) async {
    await clearSavedCatalogue();
    await $.pumpWidget(const SkimapperApp());

    await $(
      '© OpenStreetMap contributors · OpenSkiMap · Protomaps · Mapterhorn',
    ).waitUntilVisible(timeout: const Duration(seconds: 10));
  });
}
