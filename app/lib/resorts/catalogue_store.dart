import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// The saved copy of the catalogue, kept as served.
class CatalogueStore {
  CatalogueStore(this._directory);

  CatalogueStore.appSupport() : this(getApplicationSupportDirectory);

  final Future<Directory> Function() _directory;

  /// The saved copy, or null if there is none or it isn't text.
  Future<String?> read() async {
    final file = await _file();
    if (!await file.exists()) return null;
    try {
      return utf8.decode(await file.readAsBytes());
    } on FormatException {
      return null;
    }
  }

  /// Writes [body] beside the saved copy, flushed, then renames it into place, so a failure at
  /// any point leaves the previous copy whole.
  Future<void> write(String body) async {
    final file = await _file();
    final pending = await File('${file.path}.pending')
        .writeAsString(body, flush: true);
    await pending.rename(file.path);
  }

  Future<File> _file() async =>
      File('${(await _directory()).path}/catalogue.json');

  Future<void> clear() async {
    final file = await _file();
    if (await file.exists()) await file.delete();
  }
}
