import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:skimapper/map/scratch_folders.dart';

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('resort-maps-');
    addTearDown(() => root.deleteSync(recursive: true));
  });

  test("a new folder deletes those of opens whose screens are gone, never a live one's", () async {
    final folders = ScratchFolders(Future.value(root));
    final gone = await folders.newFolder();
    final live = await folders.newFolder();
    folders.release(gone);

    final fresh = await folders.newFolder();

    expect(gone.existsSync(), isFalse);
    expect(live.existsSync(), isTrue);
    expect(fresh.existsSync(), isTrue);
  });

  test(
    "clearing at launch deletes every folder an earlier launch left",
    () async {
      final leftover = Directory('${root.path}/open-earlier')..createSync();
      File('${leftover.path}/part').writeAsStringSync('bytes');

      await ScratchFolders(Future.value(root)).clearAll();

      expect(root.listSync(), isEmpty);
    },
  );

  test(
    "clearing never deletes the folder of a screen that is already open",
    () async {
      final folders = ScratchFolders(Future.value(root));
      final live = await folders.newFolder();

      await folders.clearAll();

      expect(live.existsSync(), isTrue);
    },
  );
}
