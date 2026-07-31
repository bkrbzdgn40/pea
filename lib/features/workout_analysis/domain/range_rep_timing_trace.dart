/// Final lifecycle state represented by a range-repetition timing trace.
enum RangeRepTimingTraceOutcome { active, completed, aborted, interrupted }

class RangeRepTimingTransitionTrace {
  const RangeRepTimingTransitionTrace({
    required this.type,
    required this.effectiveAt,
    required this.confirmedAt,
  });

  final String type;

  /// First observation at which the transition condition became true.
  final DateTime effectiveAt;

  /// Observation that completed the configured confirmation window.
  final DateTime confirmedAt;

  int get confirmationLagMs {
    final lag = confirmedAt.difference(effectiveAt).inMilliseconds;
    return lag < 0 ? 0 : lag;
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'type': type,
    'effective_at': effectiveAt.toIso8601String(),
    'confirmed_at': confirmedAt.toIso8601String(),
    'confirmation_lag_ms': confirmationLagMs,
  };
}

/// Privacy-minimized timing observations for one active or ended repetition.
///
/// This model intentionally records derived movement metrics and timestamps,
/// not landmarks or camera frames. P1-A uses it to diagnose sampling,
/// processing latency, transition confirmation, and cycle-integrity problems
/// before tempo coaching is re-enabled.
class RangeRepTimingTraceSnapshot {
  const RangeRepTimingTraceSnapshot({
    required this.outcome,
    this.sampleCount = 0,
    this.towardPeakSampleCount = 0,
    this.peakSampleCount = 0,
    this.returnSampleCount = 0,
    this.directionChangeCount = 0,
    this.nonMonotonicObservationCount = 0,
    this.invalidProcessingLagCount = 0,
    this.intervalSampleCount = 0,
    this.averageObservationIntervalMs,
    this.maxObservationIntervalMs,
    this.lastProcessingLagMs,
    this.maxProcessingLagMs,
    this.firstObservedAt,
    this.lastObservedAt,
    this.firstPrimaryMetric,
    this.lastPrimaryMetric,
    this.minPrimaryMetric,
    this.maxPrimaryMetric,
    this.hadVisibilityGap = false,
    this.transitions = const <RangeRepTimingTransitionTrace>[],
  });

  final RangeRepTimingTraceOutcome outcome;
  final int sampleCount;
  final int towardPeakSampleCount;
  final int peakSampleCount;
  final int returnSampleCount;
  final int directionChangeCount;
  final int nonMonotonicObservationCount;
  final int invalidProcessingLagCount;
  final int intervalSampleCount;
  final double? averageObservationIntervalMs;
  final int? maxObservationIntervalMs;
  final int? lastProcessingLagMs;
  final int? maxProcessingLagMs;
  final DateTime? firstObservedAt;
  final DateTime? lastObservedAt;
  final double? firstPrimaryMetric;
  final double? lastPrimaryMetric;
  final double? minPrimaryMetric;
  final double? maxPrimaryMetric;
  final bool hadVisibilityGap;
  final List<RangeRepTimingTransitionTrace> transitions;

  Map<String, Object?> toJson() => <String, Object?>{
    'outcome': outcome.name,
    'sample_count': sampleCount,
    'toward_peak_sample_count': towardPeakSampleCount,
    'peak_sample_count': peakSampleCount,
    'return_sample_count': returnSampleCount,
    'direction_change_count': directionChangeCount,
    'non_monotonic_observation_count': nonMonotonicObservationCount,
    'invalid_processing_lag_count': invalidProcessingLagCount,
    'interval_sample_count': intervalSampleCount,
    'average_observation_interval_ms': averageObservationIntervalMs,
    'max_observation_interval_ms': maxObservationIntervalMs,
    'last_processing_lag_ms': lastProcessingLagMs,
    'max_processing_lag_ms': maxProcessingLagMs,
    'first_observed_at': firstObservedAt?.toIso8601String(),
    'last_observed_at': lastObservedAt?.toIso8601String(),
    'first_primary_metric': firstPrimaryMetric,
    'last_primary_metric': lastPrimaryMetric,
    'min_primary_metric': minPrimaryMetric,
    'max_primary_metric': maxPrimaryMetric,
    'had_visibility_gap': hadVisibilityGap,
    'transitions': transitions
        .map((transition) => transition.toJson())
        .toList(growable: false),
  };
}
