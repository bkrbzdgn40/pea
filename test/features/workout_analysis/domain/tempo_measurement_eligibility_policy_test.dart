import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/tempo_measurement_assessment.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/range_rep_timing_trace.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/tempo_engine.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/tempo_measurement_eligibility_policy.dart';

void main() {
  final policy = TempoMeasurementEligibilityPolicy();

  test('marks a complete monotonic observed cycle eligible', () {
    final base = DateTime.utc(2026, 8, 1, 10);
    final trace = _trace(base: base);
    final tempo = _tempo();

    final result = policy.evaluate(trace: trace, measuredTempo: tempo);

    expect(result.status, TempoMeasurementStatus.eligible);
    expect(result.issues, isEmpty);
    expect(result.measuredTempo, same(tempo));
    expect(result.trace, same(trace));
  });

  test('returns typed issues when timing facts are missing', () {
    final result = policy.evaluate(trace: null, measuredTempo: null);

    expect(result.status, TempoMeasurementStatus.unavailable);
    expect(
      result.issues,
      containsAll(<TempoMeasurementIssue>[
        TempoMeasurementIssue.missingTimingTrace,
        TempoMeasurementIssue.missingTempoResult,
      ]),
    );
  });

  test('rejects a sparse recovered cycle for tempo', () {
    final result = policy.evaluate(
      trace: _trace(usedSparseCycleRecovery: true),
      measuredTempo: _tempo(),
    );

    expect(result.status, TempoMeasurementStatus.unavailable);
    expect(result.issues, contains(TempoMeasurementIssue.sparseCycleRecovered));
  });

  test('rejects a visibility-interrupted cycle for tempo', () {
    final result = policy.evaluate(
      trace: _trace(hadVisibilityGap: true),
      measuredTempo: _tempo(),
    );

    expect(result.status, TempoMeasurementStatus.unavailable);
    expect(
      result.issues,
      contains(TempoMeasurementIssue.visibilityInterrupted),
    );
  });

  test('rejects missing phase evidence and incomplete transition order', () {
    final base = DateTime.utc(2026, 8, 1, 10);
    final result = policy.evaluate(
      trace: _trace(
        base: base,
        towardPeakSampleCount: 0,
        peakSampleCount: 0,
        returnSampleCount: 0,
        transitions: <RangeRepTimingTransitionTrace>[
          _transition('startTowardPeak', base, 0),
          _transition('startReturning', base, 300),
          _transition('completeRep', base, 600),
        ],
      ),
      measuredTempo: _tempo(),
    );

    expect(
      result.issues,
      containsAll(<TempoMeasurementIssue>[
        TempoMeasurementIssue.incompleteTransitionSequence,
        TempoMeasurementIssue.missingTowardPeakEvidence,
        TempoMeasurementIssue.missingPeakEvidence,
        TempoMeasurementIssue.missingReturnEvidence,
      ]),
    );
  });

  test('rejects non-monotonic and invalid clock relationships', () {
    final base = DateTime.utc(2026, 8, 1, 10);
    final result = policy.evaluate(
      trace: _trace(
        base: base,
        nonMonotonicObservationCount: 1,
        invalidProcessingLagCount: 1,
        transitions: <RangeRepTimingTransitionTrace>[
          _transition('startTowardPeak', base, 0),
          RangeRepTimingTransitionTrace(
            type: 'reachPeak',
            effectiveAt: base.add(const Duration(milliseconds: 250)),
            confirmedAt: base.add(const Duration(milliseconds: 200)),
          ),
          _transition('startReturning', base, 400),
          _transition('completeRep', base, 700),
        ],
      ),
      measuredTempo: _tempo(),
    );

    expect(
      result.issues,
      containsAll(<TempoMeasurementIssue>[
        TempoMeasurementIssue.nonMonotonicObservation,
        TempoMeasurementIssue.invalidClockRelationship,
      ]),
    );
  });

  test('rejects excessive observation and confirmation gaps', () {
    final base = DateTime.utc(2026, 8, 1, 10);
    final result = policy.evaluate(
      trace: _trace(
        base: base,
        maxObservationIntervalMs: 351,
        transitions: <RangeRepTimingTransitionTrace>[
          RangeRepTimingTransitionTrace(
            type: 'startTowardPeak',
            effectiveAt: base,
            confirmedAt: base.add(const Duration(milliseconds: 301)),
          ),
          _transition('reachPeak', base, 400),
          _transition('startReturning', base, 600),
          _transition('completeRep', base, 800),
        ],
      ),
      measuredTempo: _tempo(),
    );

    expect(
      result.issues,
      containsAll(<TempoMeasurementIssue>[
        TempoMeasurementIssue.observationGapTooLarge,
        TempoMeasurementIssue.confirmationLagTooLarge,
      ]),
    );
  });

  test('rejects missing tempo and zero phase durations', () {
    final missing = policy.evaluate(trace: _trace(), measuredTempo: null);
    final zero = policy.evaluate(
      trace: _trace(),
      measuredTempo: _tempo(towardPeak: Duration.zero),
    );

    expect(missing.issues, contains(TempoMeasurementIssue.missingTempoResult));
    expect(
      zero.issues,
      contains(TempoMeasurementIssue.zeroOrNegativePhaseDuration),
    );
  });
}

RangeRepTimingTraceSnapshot _trace({
  DateTime? base,
  int towardPeakSampleCount = 2,
  int peakSampleCount = 1,
  int returnSampleCount = 2,
  int nonMonotonicObservationCount = 0,
  int invalidProcessingLagCount = 0,
  int maxObservationIntervalMs = 120,
  bool hadVisibilityGap = false,
  bool usedSparseCycleRecovery = false,
  List<RangeRepTimingTransitionTrace>? transitions,
}) {
  final start = base ?? DateTime.utc(2026, 8, 1, 10);
  return RangeRepTimingTraceSnapshot(
    outcome: RangeRepTimingTraceOutcome.completed,
    sampleCount: 5,
    towardPeakSampleCount: towardPeakSampleCount,
    peakSampleCount: peakSampleCount,
    returnSampleCount: returnSampleCount,
    nonMonotonicObservationCount: nonMonotonicObservationCount,
    invalidProcessingLagCount: invalidProcessingLagCount,
    maxObservationIntervalMs: maxObservationIntervalMs,
    firstObservedAt: start,
    lastObservedAt: start.add(const Duration(milliseconds: 800)),
    hadVisibilityGap: hadVisibilityGap,
    usedSparseCycleRecovery: usedSparseCycleRecovery,
    transitions:
        transitions ??
        <RangeRepTimingTransitionTrace>[
          _transition('startTowardPeak', start, 0),
          _transition('reachPeak', start, 250),
          _transition('startReturning', start, 450),
          _transition('completeRep', start, 800),
        ],
  );
}

RangeRepTimingTransitionTrace _transition(
  String type,
  DateTime base,
  int effectiveMs,
) {
  return RangeRepTimingTransitionTrace(
    type: type,
    effectiveAt: base.add(Duration(milliseconds: effectiveMs)),
    confirmedAt: base.add(Duration(milliseconds: effectiveMs + 80)),
  );
}

TempoRepResult _tempo({
  Duration towardPeak = const Duration(milliseconds: 250),
  Duration returnDuration = const Duration(milliseconds: 350),
}) {
  return TempoRepResult(
    repIndex: 1,
    eccentricDuration: towardPeak,
    bottomPauseDuration: const Duration(milliseconds: 200),
    concentricDuration: returnDuration,
    topPauseDuration: Duration.zero,
    totalRepDuration:
        towardPeak + const Duration(milliseconds: 200) + returnDuration,
    towardPeakDuration: towardPeak,
    returnDuration: returnDuration,
  );
}
