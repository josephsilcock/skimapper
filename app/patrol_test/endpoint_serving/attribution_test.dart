import 'package:patrol/patrol.dart';
import 'package:skimapper/main.dart';

void main() {
  patrolTest('credits the map and resort data sources', ($) async {
    await $.pumpWidget(const SkimapperApp());

    await $(
      '© OpenStreetMap contributors · OpenSkiMap · Protomaps · Mapterhorn',
    ).waitUntilVisible(timeout: const Duration(seconds: 10));
  });
}
