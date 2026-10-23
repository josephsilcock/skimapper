import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:path_provider/path_provider.dart';

import 'bundled_basemap.dart';
import 'fixture_feature.dart';
import 'local_map_style.dart';
import 'start_up_safe_map_platform.dart';

/// Renders the bundled fixture tile from disk and reports whether the fixture feature was drawn.
class FixtureMap extends StatefulWidget {
  const FixtureMap({
    super.key,
    required this.onFixtureChecked,
    this.basemapFile,
  });

  final ValueChanged<bool> onFixtureChecked;

  /// Defaults to installing the bundled basemap into application support.
  final String? basemapFile;

  @override
  State<FixtureMap> createState() => _FixtureMapState();
}

class _FixtureMapState extends State<FixtureMap> {
  static const _renderDeadline = Duration(seconds: 10);
  static const _pollInterval = Duration(milliseconds: 250);

  late final Future<String> _basemapFile = switch (widget.basemapFile) {
    final basemapFile? => Future.value(basemapFile),
    null => _installBasemap(),
  };
  MapLibreMapController? _controller;

  @override
  void initState() {
    super.initState();
    installStartUpSafeMapPlatform();
  }

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
    final deadline = clock.now().add(_renderDeadline);
    while (mounted && clock.now().isBefore(deadline)) {
      if (await _fixtureRendered()) return _report(found: true);
      await Future<void>.delayed(_pollInterval);
    }
    _report(found: false);
  }

  void _report({required bool found}) {
    if (mounted) widget.onFixtureChecked(found);
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
