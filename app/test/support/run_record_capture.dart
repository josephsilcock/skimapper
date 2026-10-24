import 'package:flutter/foundation.dart';

/// The run-record lines [body] writes. `debugPrint` is restored before this
/// returns, which widget tests require of foundation debug variables.
Future<List<String>> runRecordDuring(Future<void> Function() body) async {
  final logged = <String>[];
  final originalDebugPrint = debugPrint;
  debugPrint = (message, {wrapWidth}) => logged.add(message!);
  try {
    await body();
  } finally {
    debugPrint = originalDebugPrint;
  }
  return logged;
}

/// Matches a run-record line from the app: its tag and UTC ISO-8601
/// millisecond timestamp, then [text] (a regular expression).
String appRunRecordLine(String text) =>
    r'^\[app \d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\.\d{3}Z\] ' + text + r'$';
