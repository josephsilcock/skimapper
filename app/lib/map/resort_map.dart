import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'resort_manifest.dart';
import 'resort_map_style.dart';
import 'start_up_safe_map_platform.dart';

/// The only place a `MapLibreMap` is built: a resort's map, drawn from its verified local parts.
class ResortMap extends StatefulWidget {
  const ResortMap({super.key, required this.manifest, required this.parts});

  final ResortManifest manifest;

  /// Each part's verified local file.
  final Map<PartRole, String> parts;

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
    styleString: resortMapStyle(parts: widget.parts),
    initialCameraPosition: CameraPosition(
      target: _centre(widget.manifest.bounds),
      zoom: 13,
    ),
    onMapCreated: (created) => controller = created,
  );

  static LatLng _centre(Bounds bounds) => LatLng(
    (bounds.south + bounds.north) / 2,
    (bounds.west + bounds.east) / 2,
  );
}
