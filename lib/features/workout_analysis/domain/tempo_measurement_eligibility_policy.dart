import 'models/tempo_measurement_assessment.dart';
import 'range_rep_timing_trace.dart';
import 'tempo_engine.dart';

/// Measurement-integrity limits used before raw tempo may influence users.
class TempoMeasurementEligibilityConfig {
  const TempoMeasurementEligibilityConfig({
    this.maxEligibleObservationGap = const Duration(milliseconds: 350),
    this.maxEligibleConfirmationLag = const Duration(milliseconds: 300),
    this.requirePeakObservationSample = true,
    this.allowTempoAfterVisibilityGap = false,
    this.allowTempoAfterSparseRecovery = false,
  });

  final Duration maxEligibleObservationGap;
  final Duration maxEligibleConfirmationLag;
  final bool requirePeakObservationSample;
  final bool allowTempoAfterVisibilityGap;
  final bool allowTempoAfterSparseRecovery;
}

/// Decides whether one completed cycle has enough timing integrity for tempo.
///
/// This policy evaluates measurement quality only. It does not classify a
/// reliable repetition as fast, slow, or on target.
class TempoMeasurementEligibilityPolicy {
  TempoMeasurementEligibilityPolicy({
    this.config = const TempoMeasurementEligibilityConfig(),
  }) : assert(!config.maxEligibleObservationGap.isNegative),
       assert(!config.maxEligibleConfirmationLag.isNegative);

  static const List<String> _requiredTransitionSequence = <String>[
    'startTowardPeak',
    'reachPeak',
    'startReturning',
    'completeRep',
  ];

  final TempoMeasurementEligibilityConfig config;

  TempoMeasurementAssessment evaluate({
    required RangeRepTimingTraceSnapshot? trace,
    required TempoRepResult? measuredTempo,
  }) {
    final issues = <TempoMeasurementIssue>{};

    if (trace == null) {
      issues.add(TempoMeasurementIssue.missingTimingTrace);
    } else {
      _evaluateTrace(trace, issues);
    }

    if (measuredTempo == null) {
      issues.add(TempoMeasurementIssue.missingTempoResult);
    } else if (!_hasPositivePhaseDurations(measuredTempo)) {
      issues.add(TempoMeasurementIssue.zeroOrNegativePhaseDuration);
    }

    return TempoMeasurementAssessment(
      status: issues.isEmpty
          ? TempoMeasurementStatus.eligible
          : TempoMeasurementStatus.unavailable,
      issues: issues.toList(growable: false),
      measuredTempo: measuredTempo,
      trace: trace,
    );
  }

  void _evaluateTrace(
    RangeRepTimingTraceSnapshot trace,
    Set<TempoMeasurementIssue> issues,
  ) {
    if (trace.outcome != RangeRepTimingTraceOutcome.completed ||
        !_hasRequiredTransitionSequence(trace.transitions)) {
      issues.add(TempoMeasurementIssue.incompleteTransitionSequence);
    }

    if (trace.towardPeakSampleCount <= 0) {
      issues.add(TempoMeasurementIssue.missingTowardPeakEvidence);
    }
    if (config.requirePeakObservationSample && trace.peakSampleCount <= 0) {
      issues.add(TempoMeasurementIssue.missingPeakEvidence);
    }
    if (trace.returnSampleCount <= 0) {
      issues.add(TempoMeasurementIssue.missingReturnEvidence);
    }
    if (trace.nonMonotonicObservationCount > 0) {
      issues.add(TempoMeasurementIssue.nonMonotonicObservation);
    }
    if (trace.invalidProcessingLagCount > 0 ||
        !_hasValidClockRelationships(trace)) {
      issues.add(TempoMeasurementIssue.invalidClockRelationship);
    }

    final maxObservationIntervalMs = trace.maxObservationIntervalMs;
    if (maxObservationIntervalMs != null &&
        maxObservationIntervalMs >
            config.maxEligibleObservationGap.inMilliseconds) {
      issues.add(TempoMeasurementIssue.observationGapTooLarge);
    }

    if (trace.transitions.any(
      (transition) =>
          transition.confirmationLagMs >
          config.maxEligibleConfirmationLag.inMilliseconds,
    )) {
      issues.add(TempoMeasurementIssue.confirmationLagTooLarge);
    }

    if (trace.hadVisibilityGap && !config.allowTempoAfterVisibilityGap) {
      issues.add(TempoMeasurementIssue.visibilityInterrupted);
    }
    if (trace.usedSparseCycleRecovery &&
        !config.allowTempoAfterSparseRecovery) {
      issues.add(TempoMeasurementIssue.sparseCycleRecovered);
    }
  }

  bool _hasRequiredTransitionSequence(
    List<RangeRepTimingTransitionTrace> transitions,
  ) {
    final sequence = transitions
        .map((transition) => transition.type)
        .toList(growable: false);
    if (sequence.length != _requiredTransitionSequence.length) {
      return false;
    }
    for (var index = 0; index < sequence.length; index++) {
      if (sequence[index] != _requiredTransitionSequence[index]) {
        return false;
      }
    }
    return true;
  }

  bool _hasValidClockRelationships(RangeRepTimingTraceSnapshot trace) {
    final firstObservedAt = trace.firstObservedAt;
    final lastObservedAt = trace.lastObservedAt;
    if (firstObservedAt != null &&
        lastObservedAt != null &&
        lastObservedAt.isBefore(firstObservedAt)) {
      return false;
    }

    DateTime? previousEffectiveAt;
    DateTime? previousConfirmedAt;
    for (final transition in trace.transitions) {
      if (transition.confirmedAt.isBefore(transition.effectiveAt)) {
        return false;
      }
      if (previousEffectiveAt != null &&
          transition.effectiveAt.isBefore(previousEffectiveAt)) {
        return false;
      }
      if (previousConfirmedAt != null &&
          transition.confirmedAt.isBefore(previousConfirmedAt)) {
        return false;
      }
      previousEffectiveAt = transition.effectiveAt;
      previousConfirmedAt = transition.confirmedAt;
    }
    return true;
  }

  bool _hasPositivePhaseDurations(TempoRepResult tempo) {
    return tempo.towardPeakDuration.inMicroseconds > 0 &&
        tempo.returnDuration.inMicroseconds > 0 &&
        tempo.totalRepDuration.inMicroseconds > 0;
  }
}
