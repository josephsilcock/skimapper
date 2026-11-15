import 'dart:async';
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

  test("a new folder waits for a launch clean-up under way, which can't then delete it", () async {
    final held = _FirstListingHeld(root);
    final folders = ScratchFolders(Future.value(held));
    final clearing = folders.clearAll();
    var made = false;
    final making = folders.newFolder().then((_) => made = true);
    await pumpEventQueue();

    expect(made, isFalse);

    held.release();
    await clearing;
    await making;
    expect(made, isTrue);
  });

  test("a launch clean-up that failed doesn't stop a new folder", () async {
    final failing = _FirstListingHeld(root);
    final folders = ScratchFolders(Future.value(failing));
    final clearing = folders.clearAll();
    await pumpEventQueue();
    failing.fail();
    await expectLater(clearing, throwsA(isA<FileSystemException>()));

    expect((await folders.newFolder()).existsSync(), isTrue);
  });
}

/// A root whose first listing waits until [release] (or throws once told to [fail]); everything else is the real directory.
class _FirstListingHeld implements Directory {
  _FirstListingHeld(this._real);

  final Directory _real;
  final _released = Completer<void>();
  var _listings = 0;

  void release() => _released.complete();

  void fail() =>
      _released.completeError(const FileSystemException('unlistable'));

  @override
  String get path => _real.path;

  @override
  Stream<FileSystemEntity> list({
    bool recursive = false,
    bool followLinks = true,
  }) async* {
    if (_listings++ == 0) await _released.future;
    yield* _real.list(recursive: recursive, followLinks: followLinks);
  }

  @override
  Future<Directory> createTemp([String? prefix]) => _real.createTemp(prefix);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
