import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:patrol/patrol.dart';
import 'package:skimapper/main.dart';
import 'package:skimapper/map/resort_map_style.dart';

import '../support/rendered_map.dart';
import '../support/saved_catalogue.dart';

void main() {
  patrolTest(
    'runs are drawn in their difficulty styles and lifts as drag or aerial lifts, each named when zoomed in',
    ($) async {
      await clearSavedCatalogue();
      await $.pumpWidget(const SkimapperApp());
      await $('Paradiski')
          .waitUntilVisible(timeout: const Duration(seconds: 10));
      await $('Paradiski').tap();

      final drawnIn = {
        runLayerId(RunStyle.novice): {'Fixture Green'},
        runLayerId(RunStyle.easy): {'Fixture Blue'},
        runLayerId(RunStyle.intermediate): {'Fixture Red'},
        runLayerId(RunStyle.advanced): {'Fixture Black', 'Fixture Expert'},
        runLayerId(RunStyle.freeride): {'Fixture Freeride', 'Fixture Extreme'},
        runLayerId(RunStyle.unrated): {'Fixture Unrated'},
        runAreaLayerId: {'Fixture Bowl'},
        liftLayerId(LiftStyle.aerial): {
          'Fixture Chair',
          'Fixture Gondola',
          'Fixture Untyped Lift',
        },
        liftLayerId(LiftStyle.drag): {
          'Fixture Drag',
          'Fixture T-bar',
          'Fixture Platter',
          'Fixture Rope Tow',
          'Fixture Carpet',
        },
      };
      for (final MapEntry(key: layer, value: names) in drawnIn.entries) {
        expect(await renderedNames($, [layer]), names, reason: layer);
      }

      // The map frames itself once its style loads; zoom only after, so it doesn't undo the zoom.
      await expectFramedOn($, fixtureBounds);
      final controller = await resortMapController($);
      // Zoomed in on one run, then one lift (their middles: test/build/sample).
      await controller.moveCamera(
        CameraUpdate.newLatLngZoom(const LatLng(45.579, 6.8139), 17),
      );
      expect(
        await renderedNames($, [runLabelLayerId]),
        contains('Fixture Red'),
      );
      await controller.moveCamera(
        CameraUpdate.newLatLngZoom(const LatLng(45.579, 6.8215), 17),
      );
      expect(
        await renderedNames($, [liftLabelLayerId]),
        contains('Fixture Chair'),
      );
    },
  );
}
