import 'dart:convert';

import 'package:flutter/services.dart';

const basemapLayersAsset = 'assets/map/basemap-layers.json';

/// The background's style layers, generated from Protomaps' grayscale flavour and split where
/// hillshade sits between them.
class BasemapLayers {
  const BasemapLayers({required this.under, required this.over});

  final List<Object?> under;
  final List<Object?> over;

  static Future<BasemapLayers> load(AssetBundle bundle) async =>
      BasemapLayers.fromJson(await bundle.loadString(basemapLayersAsset));

  factory BasemapLayers.fromJson(String json) => switch (jsonDecode(json)) {
    {'under': List<Object?> under, 'over': List<Object?> over} => BasemapLayers(
      under: under,
      over: over,
    ),
    _ => throw const FormatException('malformed basemap layers'),
  };
}
