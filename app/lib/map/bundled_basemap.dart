import 'dart:io';

import 'package:flutter/services.dart';

const bundledBasemapAsset = 'assets/map/fixture.pmtiles';

Future<String> installBundledBasemap({
  required AssetBundle bundle,
  required Directory into,
}) async {
  final bytes = await bundle.load(bundledBasemapAsset);
  final file = File('${into.path}/fixture.pmtiles');
  await file.writeAsBytes(
    bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
    flush: true,
  );
  return file.path;
}
