import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'basemap_layers.dart';
import 'glyphs.dart';
import 'map_assets.dart';

/// The folder under which each open of a resort's map keeps its parts.
final scratchRootProvider = Provider<Future<Directory>>(
  (ref) async =>
      Directory('${(await getTemporaryDirectory()).path}/resort-maps')
          .create(recursive: true),
);

/// What every map draws with: the glyphs, installed into app support, and the basemap's layers.
final mapAssetsProvider = Provider<Future<MapAssets>>(
  (ref) async => MapAssets(
    glyphs: await installGlyphs(
      bundle: rootBundle,
      into: Directory(
        '${(await getApplicationSupportDirectory()).path}/glyphs',
      ),
    ),
    basemap: await BasemapLayers.load(rootBundle),
  ),
);
