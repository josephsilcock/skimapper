import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:skimapper/main.dart';
import 'package:skimapper/map/resort_map.dart';

import '../support/default_resort.dart';
import '../support/saved_catalogue.dart';

const _credits =
    '© OpenStreetMap contributors · OpenSkiMap · Skimap.org · Protomaps · Mapterhorn';

void main() {
  patrolTest(
    "a resort's map credits its data sources, and going back shows the list alone",
    ($) async {
      await clearSavedCatalogue();
      await clearDefaultResort();
      await $.pumpWidget(const SkimapperApp());
      await $('Paradiski')
          .waitUntilVisible(timeout: const Duration(seconds: 10));
      expect($(_credits), findsNothing);

      await $('Paradiski').tap();
      await $(_credits).waitUntilVisible(timeout: const Duration(seconds: 15));

      await $(BackButton).tap();
      await $('Espace San Bernardo').waitUntilVisible();
      expect($(_credits), findsNothing);
      expect($(ResortMap), findsNothing);
    },
  );
}
