import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'map_assets.dart';
import 'resort_manifest.dart';
import 'resort_map_style.dart';
import 'start_up_safe_map_platform.dart';

/// The only place a `MapLibreMap` is built: a resort's map, drawn from its verified local parts.
class ResortMap extends StatefulWidget {
  const ResortMap({
    super.key,
    required this.manifest,
    required this.parts,
    required this.assets,
  });

  final ResortManifest manifest;

  /// Each part's verified local file.
  final Map<PartRole, String> parts;
  final MapAssets assets;

  @override
  State<ResortMap> createState() => ResortMapState();
}

class ResortMapState extends State<ResortMap> {
  /// Once the map exists; E2E tests query what it rendered through it.
  MapLibreMapController? controller;

  @override
  void initState() {
    super.initState();
    installStartUpSafeMapPlatform();
  }

  @override
  Widget build(BuildContext context) => MapLibreMap(
    styleString: resortMapStyle(
      parts: widget.parts,
      glyphs: widget.assets.glyphs,
      basemap: widget.assets.basemap,
    ),
    initialCameraPosition: CameraPosition(
      target: _centre(widget.manifest.bounds),
      zoom: 13,
    ),
    onMapCreated: (created) => controller = created,
    onStyleLoadedCallback: _frameWholeResort,
  );

  /// "The whole resort" is the manifest's bounds, every run and lift inside them.
  void _frameWholeResort() => controller?.moveCamera(
    CameraUpdate.newLatLngBounds(
      _latLngBounds(widget.manifest.bounds),
      left: _framePadding,
      top: _framePadding,
      right: _framePadding,
      bottom: _framePadding,
    ),
  );

  static const _framePadding = 32.0;

  static LatLngBounds _latLngBounds(Bounds bounds) => LatLngBounds(
    southwest: LatLng(bounds.south, bounds.west),
    northeast: LatLng(bounds.north, bounds.east),
  );

  static LatLng _centre(Bounds bounds) => LatLng(
    (bounds.south + bounds.north) / 2,
    (bounds.west + bounds.east) / 2,
  );
}
