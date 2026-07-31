/// A DateTime-compatible clock whose elapsed time is backed by a monotonic
/// duration source.
///
/// The wall-clock anchor keeps diagnostics and persisted timestamps readable,
/// while duration calculations remain immune to system-clock adjustments.
class MonotonicDateTimeClock {
  MonotonicDateTimeClock({DateTime? anchor, Duration Function()? elapsed})
    : _anchor = anchor ?? DateTime.now(),
      _elapsed = elapsed ?? _runningStopwatchElapsed();

  final DateTime _anchor;
  final Duration Function() _elapsed;

  DateTime now() => _anchor.add(_elapsed());

  static Duration Function() _runningStopwatchElapsed() {
    final stopwatch = Stopwatch()..start();
    return () => stopwatch.elapsed;
  }
}
