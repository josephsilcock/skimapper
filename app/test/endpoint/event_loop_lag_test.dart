import 'package:flutter_test/flutter_test.dart';
import 'package:skimapper/endpoint/event_loop_lag.dart';

import '../support/run_record_capture.dart';

void main() {
  test(
    'a stretch with the event loop blocked is logged with how late it ran',
    () async {
      final logged = await runRecordDuring(() async {
        final watch = watchEventLoopLag(over: const Duration(seconds: 2));
        await Future<void>.delayed(const Duration(milliseconds: 150));
        _blockFor(const Duration(milliseconds: 600));
        await Future<void>.delayed(const Duration(milliseconds: 300));
        watch.cancel();
      });

      final lateness = logged
          .map(
            RegExp(appRunRecordLine(r'event loop late by (\d+) ms')).firstMatch,
          )
          .nonNulls
          .map((match) => int.parse(match.group(1)!));
      expect(lateness, [greaterThanOrEqualTo(400)]);
    },
  );
}

void _blockFor(Duration duration) {
  final blocked = Stopwatch()..start();
  while (blocked.elapsed < duration) {}
}
