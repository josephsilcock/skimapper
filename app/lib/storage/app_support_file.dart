import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// A text file the app keeps in its support directory, read and replaced whole.
class AppSupportFile {
  AppSupportFile(this._name, this._directory);

  AppSupportFile.appSupport(String name)
    : this(name, getApplicationSupportDirectory);

  final String _name;
  final Future<Directory> Function() _directory;

  /// The file's text, or null if there is none or it isn't text.
  Future<String?> read() async {
    final file = await _file();
    if (!await file.exists()) return null;
    try {
      return utf8.decode(await file.readAsBytes());
    } on FormatException {
      return null;
    }
  }

  /// Writes [text] beside the file, flushed, then renames it into place, so a failure at any point
  /// leaves the previous copy whole.
  Future<void> write(String text) async {
    final file = await _file();
    final pending = await File('${file.path}.pending')
        .writeAsString(text, flush: true);
    await pending.rename(file.path);
  }

  Future<File> _file() async => File('${(await _directory()).path}/$_name');

  Future<void> clear() async {
    final file = await _file();
    if (await file.exists()) await file.delete();
  }
}
