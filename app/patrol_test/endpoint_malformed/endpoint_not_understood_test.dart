import 'package:patrol/patrol.dart';
import 'package:skimapper/main.dart';

void main() {
  patrolTest('says the service response was not understood', ($) async {
    await $.pumpWidget(const SkimapperApp());

    await $('service response not understood')
        .waitUntilVisible(timeout: const Duration(seconds: 6));
  });
}
