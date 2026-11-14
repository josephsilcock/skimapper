import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:patrol/patrol.dart';
import 'package:skimapper/main.dart';
import 'package:skimapper/map/resort_map_style.dart';

import '../support/rendered_map.dart';
import '../support/saved_catalogue.dart';

void main() {
  patrolTest(
    'tapping a resort opens its map under its name, drawn from local files (Wi-Fi and cellular are cut on Android only)',
    ($) async {
      await clearSavedCatalogue();
      await $.pumpWidget(const SkimapperApp());

      await $('Paradiski')
          .waitUntilVisible(timeout: const Duration(seconds: 10));
      await $('Paradiski').tap();

      await $(AppBar).$('Paradiski').waitUntilVisible();
      expect(
        await renderedNames($, [runLineLayerId]),
        contains('Fixture Blue'),
      );

      if (Platform.isAndroid) {
        await $.platform.mobile.disableWifi();
        await $.platform.mobile.disableCellular();
        addTearDown(() async {
          await $.platform.mobile.enableWifi();
          await $.platform.mobile.enableCellular();
        });
        final controller = await resortMapController($);
        await controller.moveCamera(CameraUpdate.zoomBy(0.5));
        expect(
          await renderedNames($, [runLineLayerId]),
          contains('Fixture Blue'),
        );
      }
    },
  );
}
