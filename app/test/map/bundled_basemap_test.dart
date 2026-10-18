import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skimapper/map/bundled_basemap.dart';

void main() {
  test('copies the bundled basemap to a file on disk', () async {
    final directory = await Directory.systemTemp.createTemp('basemap');
    addTearDown(() => directory.delete(recursive: true));
    final bundle = _SingleAssetBundle(bundledBasemapAsset, [1, 2, 3]);

    final path = await installBundledBasemap(bundle: bundle, into: directory);

    expect(File(path).readAsBytesSync(), [1, 2, 3]);
  });
}

class _SingleAssetBundle extends CachingAssetBundle {
  _SingleAssetBundle(this.key, this.bytes);

  final String key;
  final List<int> bytes;

  @override
  Future<ByteData> load(String requested) async {
    if (requested != key) throw StateError('no asset $requested');
    return ByteData.sublistView(Uint8List.fromList(bytes));
  }
}
