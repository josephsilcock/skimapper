import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skimapper/map/glyphs.dart';

void main() {
  test('installs each bundled glyph range where the style reads it', () async {
    final into = Directory.systemTemp.createTempSync('glyphs-');
    addTearDown(() => into.deleteSync(recursive: true));

    final glyphs = await installGlyphs(bundle: _FakeBundle(), into: into);

    expect(
      File('$glyphs/Noto Sans Regular/0-255.pbf').readAsBytesSync(),
      utf8Bytes('assets/glyphs/Noto Sans Regular/0-255.pbf'),
    );
    expect(File('$glyphs/Noto Sans Italic/8192-8447.pbf').existsSync(), isTrue);
  });
}

Uint8List utf8Bytes(String text) => Uint8List.fromList(text.codeUnits);

/// Serves each asset as its own key's bytes.
class _FakeBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(utf8Bytes(key));
}
