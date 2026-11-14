import 'dart:io';

import '../endpoint/run_record.dart';

/// Single home for the rule that no resort data is kept: the folders opens of resort maps keep
/// their parts in, deleted once their screens are gone.
class ScratchFolders {
  ScratchFolders(this._root);

  final Future<Directory> _root;
  final _live = <String>{};

  /// A folder for one fetch, made after deleting every folder no live screen holds; a map still
  /// tearing down from a live screen's folder keeps it.
  Future<Directory> newFolder() async {
    final root = await _root;
    await _deleteAllBut(root, _live);
    final folder = await root.createTemp('open-');
    _live.add(folder.path);
    return folder;
  }

  /// At app launch, when no screen holds any folder.
  Future<void> clearAll() async => _deleteAllBut(await _root, const {});

  /// The screen holding [folder] has gone.
  void release(Directory folder) => _live.remove(folder.path);

  /// A failed clean-up is only logged: the next one tries again.
  static Future<void> _deleteAllBut(Directory root, Set<String> kept) async {
    await for (final entry in root.list()) {
      if (kept.contains(entry.path)) continue;
      try {
        await entry.delete(recursive: true);
      } on FileSystemException catch (failure) {
        recordRun('scratch clean-up failed: $failure');
      }
    }
  }
}
