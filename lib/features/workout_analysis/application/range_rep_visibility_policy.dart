const int _invalidFrameStreakResyncThreshold = 4;
const Duration _invalidDurationResyncThreshold = Duration(milliseconds: 450);

class RangeRepVisibilityAssessment {
  const RangeRepVisibilityAssessment({
    required this.invalidFrameStreak,
    required this.invalidDuration,
    required this.shouldResync,
    required this.hasResyncedCurrentRun,
    this.resyncReason,
  });

  const RangeRepVisibilityAssessment.stable()
      : invalidFrameStreak = 0,
        invalidDuration = Duration.zero,
        shouldResync = false,
        hasResyncedCurrentRun = false,
        resyncReason = null;

  final int invalidFrameStreak;
  final Duration invalidDuration;
  final bool shouldResync;
  final bool hasResyncedCurrentRun;
  final String? resyncReason;

  String get statusLabel {
    if (shouldResync) {
      return 'resync trigger';
    }
    if (hasResyncedCurrentRun) {
      return 'resynced';
    }
    if (invalidFrameStreak > 0) {
      return 'freeze';
    }
    return 'stable';
  }
}

class RangeRepVisibilityPolicy {
  int _invalidFrameStreak = 0;
  DateTime? _invalidStartedAt;
  bool _hasResyncedCurrentRun = false;
  String? _resyncReason;

  RangeRepVisibilityAssessment evaluate({
    required bool isInvalidFrame,
    required DateTime now,
  }) {
    if (!isInvalidFrame) {
      _resetInvalidRun();
      return const RangeRepVisibilityAssessment.stable();
    }

    _invalidFrameStreak += 1;
    _invalidStartedAt ??= now;

    final invalidDuration = now.difference(_invalidStartedAt!);
    var shouldResync = false;
    if (!_hasResyncedCurrentRun) {
      if (_invalidFrameStreak >= _invalidFrameStreakResyncThreshold) {
        _hasResyncedCurrentRun = true;
        _resyncReason = 'invalid streak threshold';
        shouldResync = true;
      } else if (invalidDuration >= _invalidDurationResyncThreshold) {
        _hasResyncedCurrentRun = true;
        _resyncReason = 'invalid duration threshold';
        shouldResync = true;
      }
    }

    return RangeRepVisibilityAssessment(
      invalidFrameStreak: _invalidFrameStreak,
      invalidDuration: invalidDuration,
      shouldResync: shouldResync,
      hasResyncedCurrentRun: _hasResyncedCurrentRun,
      resyncReason: _resyncReason,
    );
  }

  void _resetInvalidRun() {
    _invalidFrameStreak = 0;
    _invalidStartedAt = null;
    _hasResyncedCurrentRun = false;
    _resyncReason = null;
  }
}
