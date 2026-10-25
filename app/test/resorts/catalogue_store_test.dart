import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:skimapper/resorts/catalogue_store.dart';

void main() {
  late Directory directory;
  late CatalogueStore store;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('catalogue-store-');
    store = CatalogueStore(() async => directory);
  });
  tearDown(() => directory.deleteSync(recursive: true));

  test('reads back the body it saved, byte for byte', () async {
    await store.write('{"kind": "catalogue"}');

    expect(await store.read(), '{"kind": "catalogue"}');
  });

  test('reads nothing when nothing was saved', () async {
    expect(await store.read(), isNull);
  });

  test('clearing leaves nothing saved', () async {
    await store.write('{"kind": "catalogue"}');

    await store.clear();

    expect(await store.read(), isNull);
  });

  test('a save replaces the copy whole: a read already under way still sees the old one', () async {
    await store.write('old copy');
    final readUnderWay = (directory.listSync().single as File).openSync();
    addTearDown(readUnderWay.closeSync);

    await store.write('new copy');

    expect(String.fromCharCodes(readUnderWay.readSync(100)), 'old copy');
    expect(await store.read(), 'new copy');
  });
}
