import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/validated_rep_event_tracker.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/range_rep_validation_result.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/measurement_confidence_breakdown.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/validated_rep_event.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/symmetry_engine.dart';

void main() {
  test('accepted events are the only source of side counts and symmetry', () {
    final tracker = ValidatedRepEventTracker();

    expect(
      tracker.record(
        _event(
          attemptIndex: 1,
          acceptedRepIndex: 1,
          side: ValidatedRepSide.left,
          primaryRom: 50,
        ),
      ),
      isTrue,
    );
    expect(
      tracker.record(
        _event(
          attemptIndex: 2,
          acceptedRepIndex: 2,
          side: ValidatedRepSide.right,
          primaryRom: 50,
        ),
      ),
      isTrue,
    );

    final summary = tracker.symmetrySessionSummary;
    expect(tracker.totalRepCount, 2);
    expect(summary.leftRepCount, 1);
    expect(summary.rightRepCount, 1);
    expect(summary.romSymmetryScore, 100);
    expect(summary.overallSymmetryScore, 100);
  });

  test('invalid and duplicate attempts cannot advance side counts', () {
    final tracker = ValidatedRepEventTracker();
    final invalid = _event(
      attemptIndex: 1,
      acceptedRepIndex: null,
      side: ValidatedRepSide.left,
      status: RangeRepValidationStatus.invalid,
      reasons: const <RangeRepValidationReason>[
        RangeRepValidationReason.insufficientRom,
      ],
      primaryRom: 10,
    );

    expect(tracker.record(invalid), isTrue);
    expect(tracker.record(invalid), isFalse);
    expect(tracker.totalRepCount, 0);
    expect(tracker.symmetrySessionSummary, same(SymmetrySessionSummary.empty));
  });

  test('accepted indices must stay aligned with the main rep count', () {
    final tracker = ValidatedRepEventTracker();

    expect(
      () => tracker.record(
        _event(
          attemptIndex: 1,
          acceptedRepIndex: 2,
          side: ValidatedRepSide.left,
          primaryRom: 50,
        ),
      ),
      throwsStateError,
    );
  });

  test('measurement-quality cautions count but stay out of ROM symmetry', () {
    final tracker = ValidatedRepEventTracker();
    tracker.record(
      _event(
        attemptIndex: 1,
        acceptedRepIndex: 1,
        side: ValidatedRepSide.left,
        primaryRom: 50,
      ),
    );
    tracker.record(
      _event(
        attemptIndex: 2,
        acceptedRepIndex: 2,
        side: ValidatedRepSide.right,
        status: RangeRepValidationStatus.lowConfidence,
        reasons: const <RangeRepValidationReason>[
          RangeRepValidationReason.coverageLoss,
        ],
        primaryRom: 50,
      ),
    );

    final summary = tracker.symmetrySessionSummary;
    expect(tracker.totalRepCount, 2);
    expect(summary.leftRepCount, 1);
    expect(summary.rightRepCount, 1);
    expect(summary.rightAverageRom, isNull);
    expect(summary.romSymmetryScore, isNull);
    expect(summary.overallSymmetryScore, isNull);
  });
}

ValidatedRepEvent _event({
  required int attemptIndex,
  required int? acceptedRepIndex,
  required ValidatedRepSide? side,
  required double primaryRom,
  RangeRepValidationStatus status = RangeRepValidationStatus.valid,
  List<RangeRepValidationReason> reasons = const <RangeRepValidationReason>[],
}) {
  return ValidatedRepEvent(
    attemptIndex: attemptIndex,
    acceptedRepIndex: acceptedRepIndex,
    exerciseType: 'lunge',
    analysisKind: 'rangeRep',
    validationStatus: status,
    validationReasons: reasons,
    tempoDiagnosticReasons: const <RangeRepValidationReason>[],
    countsTowardReps: status != RangeRepValidationStatus.invalid,
    side: side,
    minPrimaryMetric: 110,
    primaryRom: primaryRom,
    worstFormMetric: 170,
    descentDuration: const Duration(milliseconds: 700),
    ascentDuration: const Duration(milliseconds: 700),
    hadFormViolation: false,
    hadCoverageDrop: reasons.contains(RangeRepValidationReason.coverageLoss),
    switchedSideDuringRep: reasons.contains(
      RangeRepValidationReason.sideSwitchDuringRep,
    ),
    completedPhaseSequence: true,
    measurementConfidence: const MeasurementConfidenceBreakdown.legacyScalar(1),
    coverageQuality: 1,
    finalScore: status == RangeRepValidationStatus.invalid ? null : 90,
    tempoAssessment: null,
    tempoIncludedInScore: false,
    completedAt: DateTime.utc(2030),
  );
}
