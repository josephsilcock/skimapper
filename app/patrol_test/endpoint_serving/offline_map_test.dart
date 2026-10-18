import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:skimapper/main.dart';

void main() {
  patrolTest('renders the bundled fixture tile from a local file (Wi-Fi and cellular are cut on Android only)', ($) async {
    if (Platform.isAndroid) {
      await $.platform.mobile.disableWifi();
      await $.platform.mobile.disableCellular();
      addTearDown(() async {
        await $.platform.mobile.enableWifi();
        await $.platform.mobile.enableCellular();
      });
    }

    await $.pumpWidget(const SkimapperApp());

    await $('map: fixture feature found')
        .waitUntilVisible(timeout: const Duration(seconds: 30));
  });
}
