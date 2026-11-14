import 'basemap_layers.dart';

/// What every resort's map draws with besides its parts: the installed glyphs and the basemap's
/// layers.
class MapAssets {
  const MapAssets({required this.glyphs, required this.basemap});

  /// The folder the glyphs were installed to.
  final String glyphs;
  final BasemapLayers basemap;
}
