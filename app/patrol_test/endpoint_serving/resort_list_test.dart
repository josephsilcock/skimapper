import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:skimapper/main.dart';

import '../support/saved_catalogue.dart';

void main() {
  patrolTest('lists the curated ski areas by name, each with its countries', (
    $,
  ) async {
    await clearSavedCatalogue();
    await $.pumpWidget(const SkimapperApp());

    await $('Espace San Bernardo')
        .waitUntilVisible(timeout: const Duration(seconds: 10));
    expect($('Paradiski'), findsOneWidget);
    expect($('Les 3 Vallées'), findsOneWidget);
    expect($('France · Italy'), findsOneWidget);
  });
}
