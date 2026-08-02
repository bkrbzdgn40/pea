import 'generic_rep_engine.dart';
import 'models/tempo_measurement_assessment.dart';
import 'range_rep_timing_trace.dart';
import 'range_rep_timing_trace_recorder.dart';
import 'tempo_engine.dart';
import 'tempo_measurement_eligibility_policy.dart';

class RangeRepTimingCompletion {
  const RangeRepTimingCompletion({
    required this.trace,
    required this.assessment,
  });

  final RangeRepTimingTraceSnapshot? trace;
  final TempoMeasurementAssessment assessment;
}

/// Owns timing-trace mutation and tempo-measurement eligibility state.
class RangeRepTimingLifecycle {
  RangeRepTimingLifecycle({
    TempoMeasurementEligibilityConfig eligibilityConfig =
        const TempoMeasurementEligibilityConfig(),
    RangeRepTimingTraceRecorder? recorder,
  }) : _eligibilityPolicy = TempoMeasurementEligibilityPolicy(
         config: eligibilityConfig,
       ),
       _recorder = recorder ?? RangeRepTimingTraceRecorder();

  final TempoMeasurementEligibilityPolicy _eligibilityPolicy;
  final RangeRepTimingTraceRecorder _recorder;

  TempoMeasurementAssessment? lastAssessment;
  int nonMonotonicObservationCount = 0;

  RangeRepTimingTraceSnapshot? get activeSnapshot => _recorder.activeSnapshot;
  RangeRepTimingTraceSnapshot? get lastEndedSnapshot =>
      _recorder.lastEndedSnapshot;

  void recordRejectedObservation() {
    nonMonotonicObservationCount++;
    _recorder.recordRejectedObservation();
  }

  void recordAcceptedFrame({
    required GenericRepEngineFrameResult result,
    required double primaryMetric,
    required DateTime observedAt,
    required DateTime processedAt,
  }) {
    if (result.repStarted) {
      _recorder.start();
    }
    if (!_recorder.isActive) {
      return;
    }
    if (result.usedSparseCycleRecovery) {
      _recorder.markSparseCycleRecovery();
    }
    _recorder
      ..record(
        phase: _timingTracePhaseFor(result),
        primaryMetric: primaryMetric,
        observedAt: observedAt,
        processedAt: processedAt,
      )
      ..addTransitions(result.confirmedTransitions);
  }

  void markVisibilityGap() {
    _recorder.markVisibilityGap();
  }

  RangeRepTimingCompletion finishCompleted(TempoRepResult? completedTempo) {
    final trace = _recorder.finish(RangeRepTimingTraceOutcome.completed);
    final assessment = _eligibilityPolicy.evaluate(
      trace: trace,
      measuredTempo: completedTempo,
    );
    lastAssessment = assessment;
    return RangeRepTimingCompletion(trace: trace, assessment: assessment);
  }

  void finishAborted() {
    _recorder.finish(RangeRepTimingTraceOutcome.aborted);
  }

  void finishInterrupted() {
    _recorder.finish(RangeRepTimingTraceOutcome.interrupted);
  }

  void reset() {
    _recorder.reset();
    lastAssessment = null;
    nonMonotonicObservationCount = 0;
  }

  GenericRepPhase _timingTracePhaseFor(GenericRepEngineFrameResult result) {
    final transitionTypes = result.confirmedTransitions
        .map((transition) => transition.type)
        .toSet();
    if (transitionTypes.contains(GenericRepTransitionType.startReturning) ||
        transitionTypes.contains(GenericRepTransitionType.completeRep)) {
      return GenericRepPhase.returning;
    }
    if (result.repStarted ||
        transitionTypes.contains(GenericRepTransitionType.reachPeak)) {
      return GenericRepPhase.towardPeak;
    }
    return result.phaseBeforeUpdate;
  }
}
