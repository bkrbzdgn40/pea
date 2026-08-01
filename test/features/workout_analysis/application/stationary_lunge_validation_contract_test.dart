import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/analysis_engine_factory.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_catalog.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_metrics.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/range_rep_coordinator.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/validated_rep_event_tracker.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_type.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/range_rep_completed_rep_detection_data.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/range_rep_engine_frame_result.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/range_rep_rep_summary.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/range_rep_validation_result.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/validated_rep_event.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/range_rep_engine.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/range_rep_validation_policy.dart';

import '../../../support/workout_analysis_test_support.dart';

void main() {
  const catalog = ExerciseCatalog();

  test(
    'completed shallow lunge cycle is invalid despite sufficient ROM delta',
    () {
      final clock = _TestClock();
      final engine = RangeRepEngine(
        config: loadExerciseConfig(
          'assets/config/exercises/stationary_lunge.json',
        ),
        now: clock.now,
      );

      _confirmDetectionTransition(
        clock,
        engine,
        angle: 170,
        confirmationWindow: const Duration(milliseconds: 101),
      );
      _confirmDetectionTransition(clock, engine, angle: 140);
      _confirmDetectionTransition(clock, engine, angle: 111);
      _confirmDetectionTransition(clock, engine, angle: 130);
      final completed = _confirmDetectionTransition(
        clock,
        engine,
        angle: 170,
        confirmationWindow: const Duration(milliseconds: 101),
      ).completedRepDetectionData;

      expect(completed, isNotNull);
      expect(completed?.minAngle, 111);
      expect(completed?.primaryRom, 29);

      final policy = RangeRepValidationPolicy(
        config: catalog
            .definitionFor(ExerciseType.lunge)
            .analysisRangeRepValidationConfig,
      );
      final validation = policy.evaluate(_summaryFromDetection(completed!));

      expect(validation.status, RangeRepValidationStatus.invalid);
      expect(validation.reasons, <RangeRepValidationReason>[
        RangeRepValidationReason.insufficientRom,
      ]);
      expect(validation.countsTowardReps, isFalse);
    },
  );

  test('shallow return-to-neutral publishes one rejected lunge attempt', () {
    final clock = _TestClock();
    final definition = catalog.definitionFor(ExerciseType.lunge);
    final config = loadExerciseConfig(definition.configAssetPath!);
    final coordinator = DefaultRangeRepCoordinator(
      engine: const AnalysisEngineFactory().createRangeRep(
        config: config,
        rangeRepContract: definition.analysisRangeRepContract,
        now: clock.now,
      ),
      config: config,
      rangeRepContract: definition.analysisRangeRepContract,
      rangeRepValidationConfig: definition.analysisRangeRepValidationConfig,
    );

    _pumpCoordinator(
      coordinator,
      clock,
      angle: 170,
      count: 3,
      spacing: const Duration(milliseconds: 120),
    );
    _driveCoordinatorUntilPhase(
      coordinator,
      clock,
      angle: 140,
      expectedPhase: 'DESCENDING',
    );
    _pumpCoordinator(
      coordinator,
      clock,
      angle: 125,
      count: 2,
      spacing: const Duration(milliseconds: 90),
    );
    final rejected = _driveCoordinatorUntilPhase(
      coordinator,
      clock,
      angle: 170,
      expectedPhase: 'NEUTRAL',
      spacing: const Duration(milliseconds: 120),
    );

    expect(rejected.stateSnapshot.repCount, 0);
    expect(rejected.stateSnapshot.calibrationMetrics.rangeRepInvalidCount, 1);
    expect(rejected.validatedRepEvent, isNotNull);
    expect(rejected.validatedRepEvent!.attemptIndex, 1);
    expect(rejected.validatedRepEvent!.acceptedRepIndex, isNull);
    expect(rejected.validatedRepEvent!.countsTowardReps, isFalse);
    expect(
      rejected.validatedRepEvent!.validationStatus,
      RangeRepValidationStatus.invalid,
    );
    expect(
      rejected.validatedRepEvent!.validationReasons,
      <RangeRepValidationReason>[RangeRepValidationReason.insufficientRom],
    );
    expect(rejected.validatedRepEvent!.side, ValidatedRepSide.left);
    expect(rejected.validatedRepEvent!.primaryRom, greaterThan(0));
    expect(
      rejected.diagnosticsUpdate.completedRepValidationStatus,
      RangeRepValidationStatus.invalid.name,
    );

    _driveCoordinatorUntilPhase(
      coordinator,
      clock,
      angle: 140,
      expectedPhase: 'DESCENDING',
    );
    _driveCoordinatorUntilPhase(
      coordinator,
      clock,
      angle: 100,
      expectedPhase: 'PEAK',
    );
    _driveCoordinatorUntilPhase(
      coordinator,
      clock,
      angle: 130,
      expectedPhase: 'ASCENDING',
    );
    final accepted = _driveCoordinatorUntilPhase(
      coordinator,
      clock,
      angle: 170,
      expectedPhase: 'NEUTRAL',
      spacing: const Duration(milliseconds: 120),
    );

    expect(accepted.stateSnapshot.repCount, 1);
    expect(accepted.stateSnapshot.calibrationMetrics.rangeRepInvalidCount, 1);
    expect(accepted.validatedRepEvent!.attemptIndex, 2);
    expect(accepted.validatedRepEvent!.acceptedRepIndex, 1);
    expect(accepted.validatedRepEvent!.countsTowardReps, isTrue);
  });

  test('visibility interruption does not create a rejected lunge attempt', () {
    final clock = _TestClock();
    final definition = catalog.definitionFor(ExerciseType.lunge);
    final config = loadExerciseConfig(definition.configAssetPath!);
    final coordinator = DefaultRangeRepCoordinator(
      engine: const AnalysisEngineFactory().createRangeRep(
        config: config,
        rangeRepContract: definition.analysisRangeRepContract,
        now: clock.now,
      ),
      config: config,
      rangeRepContract: definition.analysisRangeRepContract,
      rangeRepValidationConfig: definition.analysisRangeRepValidationConfig,
    );

    _pumpCoordinator(
      coordinator,
      clock,
      angle: 170,
      count: 3,
      spacing: const Duration(milliseconds: 120),
    );
    _driveCoordinatorUntilPhase(
      coordinator,
      clock,
      angle: 140,
      expectedPhase: 'DESCENDING',
    );

    final interrupted = coordinator.handleLifecycleInterruption(
      reason: 'visibility hard resync',
    );

    expect(interrupted.repCount, 0);
    expect(interrupted.calibrationMetrics.lastRangeRepValidationStatus, isNull);
    expect(interrupted.calibrationMetrics.rangeRepInvalidCount, 0);
  });

  test(
    'stationary lunge keeps 5+5 valid reps and rejects one shallow attempt',
    () {
      final validationConfig = catalog
          .definitionFor(ExerciseType.lunge)
          .analysisRangeRepValidationConfig;
      final policy = RangeRepValidationPolicy(config: validationConfig);
      final tracker = ValidatedRepEventTracker();
      var acceptedRepIndex = 0;
      var rejectedAttemptCount = 0;
      RangeRepValidationResult? shallowResult;

      for (var attemptIndex = 1; attemptIndex <= 11; attemptIndex += 1) {
        final isShallow = attemptIndex == 11;
        final side = attemptIndex <= 5
            ? ValidatedRepSide.left
            : attemptIndex <= 10
            ? ValidatedRepSide.right
            : ValidatedRepSide.left;
        final summary = _summary(
          repIndex: attemptIndex,
          minAngle: isShallow ? 111 : 100,
          primaryRom: isShallow ? 49 : 60,
          side: side,
        );
        final validation = policy.evaluate(summary);

        if (validation.countsTowardReps) {
          acceptedRepIndex += 1;
        } else {
          rejectedAttemptCount += 1;
          shallowResult = validation;
        }

        tracker.record(
          _event(
            summary: summary,
            validation: validation,
            acceptedRepIndex: validation.countsTowardReps
                ? acceptedRepIndex
                : null,
            side: side,
          ),
        );
      }

      expect(shallowResult?.status, RangeRepValidationStatus.invalid);
      expect(shallowResult?.reasons, <RangeRepValidationReason>[
        RangeRepValidationReason.insufficientRom,
      ]);
      expect(rejectedAttemptCount, 1);
      expect(tracker.totalRepCount, 10);
      expect(tracker.leftRepCount, 5);
      expect(tracker.rightRepCount, 5);
      expect(tracker.leftRomSampleCount, 5);
      expect(tracker.rightRomSampleCount, 5);
    },
  );
}

RangeRepRepSummary _summaryFromDetection(
  RangeRepCompletedRepDetectionData detection,
) {
  return RangeRepRepSummary(
    repIndex: detection.repIndex,
    minAngle: detection.minAngle,
    worstFormMetric: 170,
    descentDuration: detection.descentDuration,
    ascentDuration: detection.ascentDuration,
    hadFormViolation: false,
    hadCoverageDrop: false,
    switchedSideDuringRep: false,
    completedPhaseSequence: detection.completedPhaseSequence,
    selectedSideLabel: ValidatedRepSide.left.name,
    analysisKindLabel: 'rangeRep',
    startAngle: detection.startAngle,
    primaryRom: detection.primaryRom,
    confidence: 1,
    coverageQuality: 1,
  );
}

RangeRepRepSummary _summary({
  required int repIndex,
  required double minAngle,
  required double primaryRom,
  required ValidatedRepSide side,
}) {
  return RangeRepRepSummary(
    repIndex: repIndex,
    minAngle: minAngle,
    worstFormMetric: 170,
    descentDuration: const Duration(milliseconds: 700),
    ascentDuration: const Duration(milliseconds: 700),
    hadFormViolation: false,
    hadCoverageDrop: false,
    switchedSideDuringRep: false,
    completedPhaseSequence: true,
    selectedSideLabel: side.name,
    analysisKindLabel: 'rangeRep',
    startAngle: 160,
    primaryRom: primaryRom,
    confidence: 1,
    coverageQuality: 1,
  );
}

ValidatedRepEvent _event({
  required RangeRepRepSummary summary,
  required RangeRepValidationResult validation,
  required int? acceptedRepIndex,
  required ValidatedRepSide side,
}) {
  return ValidatedRepEvent(
    attemptIndex: summary.repIndex,
    acceptedRepIndex: acceptedRepIndex,
    exerciseType: ExerciseType.lunge.id,
    analysisKind: summary.analysisKindLabel!,
    validationStatus: validation.status,
    validationReasons: validation.reasons,
    tempoDiagnosticReasons: validation.tempoDiagnosticReasons,
    countsTowardReps: validation.countsTowardReps,
    side: side,
    minPrimaryMetric: summary.minAngle,
    primaryRom: summary.primaryRom,
    worstFormMetric: summary.worstFormMetric,
    descentDuration: summary.descentDuration,
    ascentDuration: summary.ascentDuration,
    hadFormViolation: summary.hadFormViolation,
    hadCoverageDrop: summary.hadCoverageDrop,
    switchedSideDuringRep: summary.switchedSideDuringRep,
    completedPhaseSequence: summary.completedPhaseSequence,
    measurementConfidence: summary.confidence,
    coverageQuality: summary.coverageQuality,
    finalScore: validation.shouldPublishScore ? 90 : null,
    tempoAssessment: null,
    tempoIncludedInScore: false,
    completedAt: DateTime.utc(2030),
  );
}

RangeRepCoordinatorFrameResult _driveCoordinatorUntilPhase(
  DefaultRangeRepCoordinator coordinator,
  _TestClock clock, {
  required double angle,
  required String expectedPhase,
  Duration spacing = const Duration(milliseconds: 90),
}) {
  for (var index = 0; index < 12; index += 1) {
    final result = _processCoordinatorFrame(coordinator, clock, angle: angle);
    clock.advance(spacing);
    if (result.stateSnapshot.currentPhase == expectedPhase) {
      return result;
    }
  }
  throw TestFailure('Expected phase $expectedPhase.');
}

void _pumpCoordinator(
  DefaultRangeRepCoordinator coordinator,
  _TestClock clock, {
  required double angle,
  required int count,
  required Duration spacing,
}) {
  for (var index = 0; index < count; index += 1) {
    _processCoordinatorFrame(coordinator, clock, angle: angle);
    clock.advance(spacing);
  }
}

RangeRepCoordinatorFrameResult _processCoordinatorFrame(
  DefaultRangeRepCoordinator coordinator,
  _TestClock clock, {
  required double angle,
}) {
  final left = RangeRepSideMetrics(
    side: RangeRepSide.left,
    primaryAngle: angle,
    formMetric: angle,
    hasPrimaryAngle: true,
    hasFormMetric: true,
    sideConfidence: 1,
  );
  return coordinator.processFrame(
    metrics: ExerciseMetrics(
      primaryAngle: angle,
      formMetric: angle,
      hasPrimaryAngle: true,
      hasFormMetric: true,
      hasPose: true,
      landmarks: const <PoseLandmark>[],
      leftRangeRepMetrics: left,
      rightRangeRepMetrics: const RangeRepSideMetrics.unavailable(
        RangeRepSide.right,
      ),
    ),
    now: clock.now(),
    isAcceptedPoseFrame: true,
    didBecomeStableTracking: false,
    qualityAcceptedRangeRepSides: const <RangeRepSide>{RangeRepSide.left},
    preferredRangeRepSide: RangeRepSide.left,
  );
}

class _TestClock {
  DateTime _current = DateTime(2026, 1, 1, 12);

  DateTime now() => _current;

  void advance(Duration duration) {
    _current = _current.add(duration);
  }
}

RangeRepEngineFrameResult _confirmDetectionTransition(
  _TestClock clock,
  RangeRepEngine engine, {
  required double angle,
  Duration confirmationWindow = const Duration(milliseconds: 81),
}) {
  engine.updateDetectionFrame(primaryMetric: angle);
  clock.advance(confirmationWindow);
  return engine.updateDetectionFrame(primaryMetric: angle);
}
