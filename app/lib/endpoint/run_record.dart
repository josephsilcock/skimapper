import 'package:flutter/foundation.dart';

/// Writes one app line of the E2E run record, stamped in UTC to the millisecond
/// so it lines up with the harness's lines. Debug builds only.
void recordRun(String text) {
  if (!kDebugMode) return;
  debugPrint('[app ${_utcMillis(DateTime.now())}] $text');
}

String _utcMillis(DateTime time) =>
    '${time.toUtc().toIso8601String().substring(0, 23)}Z';
