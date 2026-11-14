import 'dart:io';

import 'package:flutter/services.dart';

/// The bundled glyphs: the fonts the style's labels use, over Latin and its punctuation.
const _fonts = ['Noto Sans Regular', 'Noto Sans Medium', 'Noto Sans Italic'];
const _ranges = ['0-255', '256-511', '8192-8447'];

/// Installs the bundled glyphs under [into], returning the folder the style reads them from:
/// MapLibre reads glyphs only from a URL, so the assets are copied out to files.
Future<String> installGlyphs({
  required AssetBundle bundle,
  required Directory into,
}) async {
  for (final font in _fonts) {
    await Directory('${into.path}/$font').create(recursive: true);
    for (final range in _ranges) {
      await _install(bundle, '$font/$range.pbf', into);
    }
  }
  return into.path;
}

Future<void> _install(AssetBundle bundle, String glyph, Directory into) async {
  final bytes = await bundle.load('assets/glyphs/$glyph');
  await File('${into.path}/$glyph').writeAsBytes(
    bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
    flush: true,
  );
}
