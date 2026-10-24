/// Blocks the calling isolate for [duration], as a frozen UI isolate would be.
void blockFor(Duration duration) {
  final blocked = Stopwatch()..start();
  while (blocked.elapsed < duration) {}
}
