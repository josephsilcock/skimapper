import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:path_provider/path_provider.dart';

import 'bundled_basemap.dart';
import 'fixture_feature.dart';
import 'local_map_style.dart';

/// Renders the bundled fixture tile from disk and reports whether the fixture feature was drawn.
class FixtureMap extends StatefulWidget {
  const FixtureMap({super.key, required this.onFixtureChecked});

  final ValueChanged<bool> onFixtureChecked;

  @override
  State<FixtureMap> createState() => _FixtureMapState();
}

class _FixtureMapState extends State<FixtureMap> {
  static const _renderDeadline = Duration(seconds: 10);
  static const _pollInterval = Duration(milliseconds: 250);

  late final Future<String> _basemapFile = _installBasemap();
  MapLibreMapController? _controller;

  Future<String> _installBasemap() async => installBundledBasemap(
    bundle: rootBundle,
    into: await getApplicationSupportDirectory(),
  );

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: _basemapFile,
    builder: (context, snapshot) => switch (snapshot.data) {
      final basemapFile? => MapLibreMap(
        styleString: localMapStyle(basemapFile: basemapFile),
        initialCameraPosition: const CameraPosition(
          target: LatLng(45.5, 7),
          zoom: 8,
        ),
        onMapCreated: (controller) => _controller = controller,
        onStyleLoadedCallback: _checkFixtureRendered,
      ),
      null => const SizedBox.expand(),
    },
  );

  Future<void> _checkFixtureRendered() async {
    final deadline = DateTime.now().add(_renderDeadline);
    while (DateTime.now().isBefore(deadline)) {
      if (await _fixtureRendered()) return widget.onFixtureChecked(true);
      await Future<void>.delayed(_pollInterval);
    }
    widget.onFixtureChecked(false);
  }

  Future<bool> _fixtureRendered() async {
    // The rect sits at the map's top-left corner: at the camera's zoom the fixture polygon
    // (tools/fixtures/make_fixture_pmtiles.py) covers it, in both Android pixels and iOS points.
    final rendered = await _controller!.queryRenderedFeaturesInRect(
      const Rect.fromLTWH(0, 0, 20, 20),
      [fixtureLayerId],
      null,
    );
    return containsFixtureFeature(rendered);
  }
}
