import 'dart:async';

import '../endpoint/run_record.dart';

const _tick = Duration(milliseconds: 100);
const _worthLogging = Duration(milliseconds: 250);

/// Logs each time the event loop runs a tick late by more than [_worthLogging],
/// for the period [over]; cancel the returned timer to stop sooner.
Timer watchEventLoopLag({required Duration over}) {
  final sinceStart = Stopwatch()..start();
  var lastTick = Duration.zero;
  return Timer.periodic(_tick, (timer) {
    final now = sinceStart.elapsed;
    final late = now - lastTick - _tick;
    lastTick = now;
    if (late > _worthLogging) {
      recordRun('event loop late by ${late.inMilliseconds} ms');
    }
    if (now >= over) timer.cancel();
  });
}
