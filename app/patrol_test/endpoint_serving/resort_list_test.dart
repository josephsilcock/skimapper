import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:skimapper/main.dart';

void main() {
  patrolTest('lists the curated ski areas by name, each with its countries', (
    $,
  ) async {
    await $.pumpWidget(const SkimapperApp());

    await $('Espace San Bernardo')
        .waitUntilVisible(timeout: const Duration(seconds: 10));
    expect($('Paradiski'), findsOneWidget);
    expect($('Les 3 Vallées'), findsOneWidget);
    expect($('France · Italy'), findsOneWidget);
  });
}
