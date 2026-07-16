class AnalysisVisibilityGapWindow {
  AnalysisVisibilityGapWindow({required this.graceDuration});

  final Duration graceDuration;

  DateTime? _startedAt;

  bool get isActive => _startedAt != null;

  DateTime? get startedAt => _startedAt;

  void begin(DateTime now) {
    _startedAt ??= now;
  }

  Duration? elapsedAt(DateTime now) {
    final startedAt = _startedAt;
    if (startedAt == null) {
      return null;
    }

    final elapsed = now.difference(startedAt);
    return elapsed.isNegative ? Duration.zero : elapsed;
  }

  bool isWithinGraceAt(DateTime now) {
    final elapsed = elapsedAt(now);
    return elapsed != null && elapsed < graceDuration;
  }

  bool hasExpiredAt(DateTime now) {
    final elapsed = elapsedAt(now);
    return elapsed != null && elapsed >= graceDuration;
  }

  Duration? consume(DateTime now) {
    final elapsed = elapsedAt(now);
    _startedAt = null;
    return elapsed;
  }

  void reset() {
    _startedAt = null;
  }
}
