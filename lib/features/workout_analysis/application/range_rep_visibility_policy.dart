const Duration briefOcclusionGraceDuration = Duration(milliseconds: 1500);

class RangeRepVisibilityAssessment {
  const RangeRepVisibilityAssessment({
    required this.invalidFrameStreak,
    required this.invalidDuration,
    required this.didStartInvalidRun,
    required this.isInBriefOcclusion,
    required this.shouldResync,
    required this.hasResyncedCurrentRun,
    this.resyncReason,
  });

  const RangeRepVisibilityAssessment.stable()
    : invalidFrameStreak = 0,
      invalidDuration = Duration.zero,
      didStartInvalidRun = false,
      isInBriefOcclusion = false,
      shouldResync = false,
      hasResyncedCurrentRun = false,
      resyncReason = null;

  final int invalidFrameStreak;
  final Duration invalidDuration;
  final bool didStartInvalidRun;
  final bool isInBriefOcclusion;
  final bool shouldResync;
  final bool hasResyncedCurrentRun;
  final String? resyncReason;

  String get statusLabel {
    if (shouldResync) {
      return 'hard_resync';
    }
    if (hasResyncedCurrentRun) {
      return 'hard_resynced';
    }
    if (isInBriefOcclusion) {
      return 'brief_freeze';
    }
    return 'stable';
  }
}

class RangeRepVisibilityPolicy {
  int _invalidFrameStreak = 0;
  DateTime? _invalidStartedAt;
  bool _hasResyncedCurrentRun = false;
  String? _resyncReason;

  bool get hasActiveInvalidRun => _invalidStartedAt != null;

  RangeRepVisibilityAssessment evaluate({
    required bool isInvalidFrame,
    required DateTime now,
  }) {
    if (!isInvalidFrame) {
      reset();
      return const RangeRepVisibilityAssessment.stable();
    }

    final didStartInvalidRun = _invalidStartedAt == null;
    _invalidFrameStreak += 1;
    _invalidStartedAt ??= now;

    final invalidDuration = now.difference(_invalidStartedAt!);
    var shouldResync = false;
    if (!_hasResyncedCurrentRun) {
      if (invalidDuration >= briefOcclusionGraceDuration) {
        _hasResyncedCurrentRun = true;
        _resyncReason = 'brief occlusion grace exceeded';
        shouldResync = true;
      }
    }

    return RangeRepVisibilityAssessment(
      invalidFrameStreak: _invalidFrameStreak,
      invalidDuration: invalidDuration,
      didStartInvalidRun: didStartInvalidRun,
      isInBriefOcclusion: !_hasResyncedCurrentRun,
      shouldResync: shouldResync,
      hasResyncedCurrentRun: _hasResyncedCurrentRun,
      resyncReason: _resyncReason,
    );
  }

  void reset() {
    _invalidFrameStreak = 0;
    _invalidStartedAt = null;
    _hasResyncedCurrentRun = false;
    _resyncReason = null;
  }
}
