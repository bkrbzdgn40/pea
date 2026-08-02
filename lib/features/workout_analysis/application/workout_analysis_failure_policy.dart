/// Failure categories that require different live-analysis recovery behavior.
enum WorkoutAnalysisFailureKind { processingException, poseDetectionTimeout }

/// User-facing disposition selected after one frame-processing failure.
enum WorkoutAnalysisFailureDisposition { recovering, blocked }

class WorkoutAnalysisFailureDecision {
  const WorkoutAnalysisFailureDecision({
    required this.kind,
    required this.disposition,
    required this.consecutiveFailureCount,
  });

  final WorkoutAnalysisFailureKind kind;
  final WorkoutAnalysisFailureDisposition disposition;
  final int consecutiveFailureCount;

  bool get isBlocked =>
      disposition == WorkoutAnalysisFailureDisposition.blocked;
}

/// Stateful circuit-breaker policy for the live pose-analysis pipeline.
///
/// A detector timeout is treated as an immediate hard failure because the
/// underlying native operation cannot be cancelled safely. Ordinary processing
/// exceptions are allowed to recover automatically until the configured
/// consecutive-failure threshold is reached.
class WorkoutAnalysisFailurePolicy {
  WorkoutAnalysisFailurePolicy({this.consecutiveFailureThreshold = 3}) {
    if (consecutiveFailureThreshold < 1) {
      throw ArgumentError.value(
        consecutiveFailureThreshold,
        'consecutiveFailureThreshold',
        'Must be at least one.',
      );
    }
  }

  final int consecutiveFailureThreshold;

  int _consecutiveFailureCount = 0;
  bool _isBlocked = false;

  int get consecutiveFailureCount => _consecutiveFailureCount;
  bool get isBlocked => _isBlocked;

  WorkoutAnalysisFailureDecision recordFailure(
    WorkoutAnalysisFailureKind kind,
  ) {
    _consecutiveFailureCount++;
    _isBlocked =
        kind == WorkoutAnalysisFailureKind.poseDetectionTimeout ||
        _consecutiveFailureCount >= consecutiveFailureThreshold;

    return WorkoutAnalysisFailureDecision(
      kind: kind,
      disposition: _isBlocked
          ? WorkoutAnalysisFailureDisposition.blocked
          : WorkoutAnalysisFailureDisposition.recovering,
      consecutiveFailureCount: _consecutiveFailureCount,
    );
  }

  /// Returns whether a previous failure state was cleared.
  bool recordSuccess() {
    final didRecover = _consecutiveFailureCount > 0 || _isBlocked;
    reset();
    return didRecover;
  }

  void reset() {
    _consecutiveFailureCount = 0;
    _isBlocked = false;
  }
}
