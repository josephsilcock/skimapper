import 'package:patrol/patrol.dart';
import 'package:skimapper/main.dart';

void main() {
  patrolTest('says the service could not be reached, within seconds', (
    $,
  ) async {
    await $.pumpWidget(const SkimapperApp());

    await $('service could not be reached')
        .waitUntilVisible(timeout: const Duration(seconds: 6));
  });
}
