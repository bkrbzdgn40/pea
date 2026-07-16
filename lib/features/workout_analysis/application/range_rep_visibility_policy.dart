import '../domain/analysis_visibility_gap_window.dart';
import '../domain/range_rep_diagnostics.dart';

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
  final AnalysisVisibilityGapWindow _invalidRunWindow =
      AnalysisVisibilityGapWindow(
        graceDuration: rangeRepVisibilityGapGraceDuration,
      );
  bool _hasResyncedCurrentRun = false;
  String? _resyncReason;

  bool get hasActiveInvalidRun => _invalidRunWindow.isActive;

  RangeRepVisibilityAssessment evaluate({
    required bool isInvalidFrame,
    required DateTime now,
  }) {
    if (!isInvalidFrame) {
      reset();
      return const RangeRepVisibilityAssessment.stable();
    }

    final didStartInvalidRun = !_invalidRunWindow.isActive;
    _invalidFrameStreak += 1;
    _invalidRunWindow.begin(now);

    final invalidDuration = _invalidRunWindow.elapsedAt(now) ?? Duration.zero;
    final shouldResync = _markResyncedIfGraceExceeded(now: now);

    return _currentAssessment(
      invalidDuration: invalidDuration,
      didStartInvalidRun: didStartInvalidRun,
      shouldResync: shouldResync,
    );
  }

  RangeRepVisibilityAssessment evaluateRecovery({required DateTime now}) {
    if (!_invalidRunWindow.isActive) {
      return const RangeRepVisibilityAssessment.stable();
    }

    final invalidDuration = _invalidRunWindow.elapsedAt(now) ?? Duration.zero;
    final shouldResync = _markResyncedIfGraceExceeded(now: now);

    return _currentAssessment(
      invalidDuration: invalidDuration,
      didStartInvalidRun: false,
      shouldResync: shouldResync,
    );
  }

  void reset() {
    _invalidFrameStreak = 0;
    _invalidRunWindow.reset();
    _hasResyncedCurrentRun = false;
    _resyncReason = null;
  }

  bool _markResyncedIfGraceExceeded({required DateTime now}) {
    if (_hasResyncedCurrentRun || !_invalidRunWindow.hasExpiredAt(now)) {
      return false;
    }

    _hasResyncedCurrentRun = true;
    _resyncReason = 'brief occlusion grace exceeded';
    return true;
  }

  RangeRepVisibilityAssessment _currentAssessment({
    required Duration invalidDuration,
    required bool didStartInvalidRun,
    required bool shouldResync,
  }) {
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
}
