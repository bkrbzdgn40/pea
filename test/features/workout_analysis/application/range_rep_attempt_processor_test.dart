import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/engine_kind.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/range_rep_attempt_processor.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/range_rep_rep_outcome_tracker.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_config.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/range_rep_aborted_attempt_detection_data.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/range_rep_contract.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/range_rep_validation_result.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/validated_rep_event.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/range_rep_diagnostics.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/range_rep_validation_policy.dart';

void main() {
  const processor = RangeRepAttemptProcessor();

  test('completed attempt returns the validated event and score state', () {
    const validationConfig = RangeRepValidationConfig(
      minAcceptableRomDelta: 40,
    );
    final tracker = _tracker(validationConfig);
    _trackLeftRepContext(tracker);

    final result = processor.processCompleted(
      outcomeTracker: tracker,
      completedRepCoreData: _completedRep(),
      postUpdateDiagnostics: const RangeRepDiagnosticsSnapshot(),
      tempoAssessment: null,
      completedAt: DateTime.utc(2030),
      engineLastRepRom: 80,
      config: _config(),
      rangeRepContract: RangeRepContracts.squat,
      rangeRepValidationConfig: validationConfig,
    );

    expect(result, isNotNull);
    expect(result!.validatedRepEvent.attemptIndex, 1);
    expect(result.validatedRepEvent.acceptedRepIndex, 1);
    expect(result.validatedRepEvent.side, ValidatedRepSide.left);
    expect(result.validatedRepEvent.countsTowardReps, isTrue);
    expect(result.validatedRepEvent.finalScore, result.lastRepScore);
    expect(result.lastRepScore, 100);
    expect(result.lastAcceptedRepRom, 80);
    expect(result.lastRepScoreBreakdown, isNotNull);
    expect(result.shouldClearTempoAssessment, isFalse);
    expect(tracker.rangeRepAcceptedCount, 1);
  });

  test('invalid completion clears published score and accepted ROM', () {
    const validationConfig = RangeRepValidationConfig(
      minAcceptableRomDelta: 120,
    );
    final tracker = _tracker(validationConfig);

    final result = processor.processCompleted(
      outcomeTracker: tracker,
      completedRepCoreData: _completedRep(),
      postUpdateDiagnostics: const RangeRepDiagnosticsSnapshot(),
      tempoAssessment: null,
      completedAt: DateTime.utc(2030),
      engineLastRepRom: 80,
      config: _config(),
      rangeRepContract: RangeRepContracts.squat,
      rangeRepValidationConfig: validationConfig,
    );

    expect(result, isNotNull);
    expect(
      result!.validatedRepEvent.validationStatus,
      RangeRepValidationStatus.invalid,
    );
    expect(result.validatedRepEvent.finalScore, isNull);
    expect(result.lastRepScore, 0);
    expect(result.lastAcceptedRepRom, 0);
    expect(result.lastRepScoreBreakdown, isNull);
    expect(tracker.rangeRepAcceptedCount, 0);
  });

  test('duplicate engine completion is ignored', () {
    const validationConfig = RangeRepValidationConfig(
      minAcceptableRomDelta: 40,
    );
    final tracker = _tracker(validationConfig);
    final completedRep = _completedRep();

    final first = processor.processCompleted(
      outcomeTracker: tracker,
      completedRepCoreData: completedRep,
      postUpdateDiagnostics: const RangeRepDiagnosticsSnapshot(),
      tempoAssessment: null,
      completedAt: DateTime.utc(2030),
      engineLastRepRom: 80,
      config: _config(),
      rangeRepContract: RangeRepContracts.squat,
      rangeRepValidationConfig: validationConfig,
    );
    final duplicate = processor.processCompleted(
      outcomeTracker: tracker,
      completedRepCoreData: completedRep,
      postUpdateDiagnostics: const RangeRepDiagnosticsSnapshot(),
      tempoAssessment: null,
      completedAt: DateTime.utc(2030, 1, 1, 0, 0, 1),
      engineLastRepRom: 80,
      config: _config(),
      rangeRepContract: RangeRepContracts.squat,
      rangeRepValidationConfig: validationConfig,
    );

    expect(first, isNotNull);
    expect(duplicate, isNull);
    expect(tracker.rangeRepAcceptedCount, 1);
  });

  test('shallow abort emits one invalid event and clears rep output', () {
    const validationConfig = RangeRepValidationConfig(
      invalidateAbortToNeutralAsInsufficientRom: true,
    );
    final tracker = _tracker(validationConfig);
    _trackLeftRepContext(tracker);

    final result = processor.processShallowAbort(
      outcomeTracker: tracker,
      invalidateAbortToNeutralAsInsufficientRom: true,
      abortedAttemptData: const RangeRepAbortedAttemptDetectionData(
        minAngle: 145,
        startAngle: 170,
        primaryRom: 25,
        descentDuration: Duration(milliseconds: 500),
      ),
      currentFormMetric: 35,
      hadFormViolation: false,
      completedAt: DateTime.utc(2030),
    );

    expect(result, isNotNull);
    expect(
      result!.validatedRepEvent.validationStatus,
      RangeRepValidationStatus.invalid,
    );
    expect(
      result.validatedRepEvent.validationReasons,
      contains(RangeRepValidationReason.insufficientRom),
    );
    expect(result.validatedRepEvent.acceptedRepIndex, isNull);
    expect(result.lastRepScore, 0);
    expect(result.lastAcceptedRepRom, 0);
    expect(result.lastRepScoreBreakdown, isNull);
    expect(result.shouldClearTempoAssessment, isTrue);
    expect(tracker.rangeRepInvalidCount, 1);
  });
}

RangeRepRepOutcomeTracker _tracker(RangeRepValidationConfig config) {
  return RangeRepRepOutcomeTracker(
    validationPolicy: RangeRepValidationPolicy(config: config),
  );
}

void _trackLeftRepContext(RangeRepRepOutcomeTracker tracker) {
  tracker.trackRepContext(
    engineKind: EngineKind.rangeRep,
    diagnostics: const RangeRepDiagnosticsSnapshot(hasActiveRepPhase: true),
    selectedSideLabel: 'left',
  );
}

RangeRepCompletedRepCoreData _completedRep() {
  return const RangeRepCompletedRepCoreData(
    repIndex: 1,
    minAngle: 90,
    startAngle: 170,
    primaryRom: 80,
    worstFormMetric: 35,
    descentDuration: Duration(seconds: 2),
    ascentDuration: Duration(seconds: 1),
    hadFormViolation: false,
    completedPhaseSequence: true,
  );
}

ExerciseConfig _config() {
  return ExerciseConfig(
    name: 'Attempt processor fixture',
    primaryJoint: PoseLandmarkType.leftKnee,
    joint1: PoseLandmarkType.leftHip,
    joint2: PoseLandmarkType.leftAnkle,
    thresholdNeutral: 170,
    thresholdActive: 140,
    thresholdPeak: 90,
    idealDescentSeconds: 2,
    idealAscentSeconds: 1,
    formThreshold: 45,
    targetMinAngle: 90,
    tempoPenaltyPerSecond: 20,
  );
}
