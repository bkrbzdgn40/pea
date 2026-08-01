import '../range_rep_timing_trace.dart';
import '../tempo_engine.dart';

/// Whether the raw timing observations for one completed repetition are
/// reliable enough to support tempo coaching.
enum TempoMeasurementStatus { eligible, unavailable }

/// Machine-readable reasons why a completed repetition cannot be used for
/// tempo coaching.
enum TempoMeasurementIssue {
  missingTimingTrace,
  missingTempoResult,
  incompleteTransitionSequence,
  missingTowardPeakEvidence,
  missingPeakEvidence,
  missingReturnEvidence,
  nonMonotonicObservation,
  invalidClockRelationship,
  observationGapTooLarge,
  confirmationLagTooLarge,
  visibilityInterrupted,
  sparseCycleRecovered,
  zeroOrNegativePhaseDuration,
}

/// Typed Tempo Measurement V2 result for one completed range repetition.
///
/// [measuredTempo] preserves the raw timing output for developer diagnostics.
/// Callers must check [status] before using it for scoring, coaching, voice, or
/// session aggregation.
class TempoMeasurementAssessment {
  TempoMeasurementAssessment({
    required this.status,
    required List<TempoMeasurementIssue> issues,
    required this.measuredTempo,
    required this.trace,
  }) : issues = List<TempoMeasurementIssue>.unmodifiable(issues);

  final TempoMeasurementStatus status;
  final List<TempoMeasurementIssue> issues;
  final TempoRepResult? measuredTempo;
  final RangeRepTimingTraceSnapshot? trace;

  bool get isEligible => status == TempoMeasurementStatus.eligible;

  Map<String, Object?> toJson() => <String, Object?>{
    'status': status.name,
    'issues': issues.map((issue) => issue.name).toList(growable: false),
    'measured_tempo': _serializeTempo(measuredTempo),
  };

  static Map<String, Object?>? _serializeTempo(TempoRepResult? tempo) {
    if (tempo == null) {
      return null;
    }
    return <String, Object?>{
      'rep_index': tempo.repIndex,
      'eccentric_ms': tempo.eccentricDuration.inMilliseconds,
      'bottom_pause_ms': tempo.bottomPauseDuration.inMilliseconds,
      'concentric_ms': tempo.concentricDuration.inMilliseconds,
      'top_pause_ms': tempo.topPauseDuration.inMilliseconds,
      'total_rep_ms': tempo.totalRepDuration.inMilliseconds,
      'toward_peak_ms': tempo.towardPeakDuration.inMilliseconds,
      'return_ms': tempo.returnDuration.inMilliseconds,
    };
  }
}
