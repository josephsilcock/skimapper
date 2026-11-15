import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../endpoint/run_record.dart';

/// A text file the app keeps in its support directory, read and replaced whole.
class AppSupportFile {
  AppSupportFile(this._name, this._directory);

  AppSupportFile.appSupport(String name)
    : this(name, getApplicationSupportDirectory);

  final String _name;
  final Future<Directory> Function() _directory;
  Future<void> _writes = Future.value();

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

  /// Writes run one at a time, in the order they were made, so the newest lands last.
  Future<void> write(String text) =>
      _writes = _writes.then((_) => _replaceReported(text));

  /// A failed write keeps the previous copy; it is reported, not shown or thrown.
  Future<void> _replaceReported(String text) async {
    try {
      await _replace(text);
    } catch (failure, stack) {
      recordRun('$_name write failed: $failure');
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: failure,
          stack: stack,
          library: 'storage',
          context: ErrorDescription('while writing $_name'),
        ),
      );
    }
  }

  /// Writes [text] beside the file, flushed, then renames it into place, so a failure at any point
  /// leaves the previous copy whole.
  Future<void> _replace(String text) async {
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
