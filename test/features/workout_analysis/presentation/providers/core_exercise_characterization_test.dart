import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/workout_state.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_type.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_feedback_code.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_phase.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/range_rep_timing_trace.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/exercise_config_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/pose_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/selected_exercise_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/workout_controller.dart';

import '../../../../support/workout_analysis_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Core exercise controller characterization', () {
    test('squat freezes one valid production-path repetition', () async {
      final harness = await _createHarness(ExerciseType.squat);
      addTearDown(harness.dispose);

      await _completeRangeRep(
        harness,
        neutralPose: buildSquatPose(angle: 170),
        activePose: buildSquatPose(angle: 140),
        peakPose: buildSquatPose(angle: 90),
        returningPose: buildSquatPose(angle: 110),
      );

      _expectValidRangeRepCharacterization(
        harness,
        expectedExercise: ExerciseType.squat,
        expectedSelectedSide: 'left',
      );
    });

    test('push-up freezes one valid production-path repetition', () async {
      final harness = await _createHarness(ExerciseType.pushUp);
      addTearDown(harness.dispose);

      await _completeRangeRep(
        harness,
        neutralPose: buildPushUpPose(elbowAngle: 170),
        activePose: buildPushUpPose(elbowAngle: 125),
        peakPose: buildPushUpPose(elbowAngle: 85),
        returningPose: buildPushUpPose(elbowAngle: 115),
      );

      _expectValidRangeRepCharacterization(
        harness,
        expectedExercise: ExerciseType.pushUp,
        expectedSelectedSide: 'left',
      );
    });

    test('biceps curl freezes one valid bilateral repetition', () async {
      final harness = await _createHarness(ExerciseType.bicepsCurl);
      addTearDown(harness.dispose);

      await _completeRangeRep(
        harness,
        neutralPose: buildBicepsCurlPose(
          leftPrimaryAngle: 160,
          rightPrimaryAngle: 162,
        ),
        activePose: buildBicepsCurlPose(
          leftPrimaryAngle: 134,
          rightPrimaryAngle: 136,
        ),
        peakPose: buildBicepsCurlPose(
          leftPrimaryAngle: 74,
          rightPrimaryAngle: 74,
        ),
        returningPose: buildBicepsCurlPose(
          leftPrimaryAngle: 98,
          rightPrimaryAngle: 98,
        ),
        completionPose: buildBicepsCurlPose(
          leftPrimaryAngle: 160,
          rightPrimaryAngle: 158,
        ),
      );

      _expectValidRangeRepCharacterization(
        harness,
        expectedExercise: ExerciseType.bicepsCurl,
        expectedSelectedSide: null,
      );
      expect(harness.state.lastRepROM, closeTo(74.0, 0.001));
      expect(
        harness.state.calibrationMetrics.lastRepRomScore,
        closeTo(100.0, 0.001),
      );
    });

    test('plank freezes stable hold timing and feedback semantics', () async {
      final harness = await _createHarness(ExerciseType.plank);
      addTearDown(harness.dispose);

      await _establishHold(harness, buildPlankPose());

      _expectHoldCharacterization(
        harness,
        expectedExercise: ExerciseType.plank,
      );
    });

    test('wall sit freezes stable hold timing and feedback semantics', () async {
      final harness = await _createHarness(ExerciseType.wallSit);
      addTearDown(harness.dispose);

      await _establishHold(harness, buildWallSitPose());

      _expectHoldCharacterization(
        harness,
        expectedExercise: ExerciseType.wallSit,
      );
    });
  });
}

Future<_ControllerHarness> _createHarness(ExerciseType exercise) async {
  final detector = TestQueuedPoseDetector();
  final clock = TestFakeClock();
  final container = ProviderContainer(
    overrides: <Override>[
      selectedExerciseProvider.overrideWith((ref) => exercise),
      poseDetectorProvider.overrideWith((ref) => detector),
      workoutClockProvider.overrideWithValue(clock.now),
    ],
  );
  await container.read(exerciseConfigProvider.future);
  final subscription = container.listen<WorkoutState>(
    workoutControllerProvider,
    (previous, next) {},
    fireImmediately: true,
  );

  return _ControllerHarness(
    container: container,
    subscription: subscription,
    controller: container.read(workoutControllerProvider.notifier),
    detector: detector,
    clock: clock,
  );
}

Future<void> _completeRangeRep(
  _ControllerHarness harness, {
  required Pose neutralPose,
  required Pose activePose,
  required Pose peakPose,
  required Pose returningPose,
  Pose? completionPose,
}) async {
  await _pumpPose(
    harness,
    neutralPose,
    count: 3,
    spacing: const Duration(milliseconds: 120),
  );
  await _driveUntilPhase(
    harness,
    activePose,
    expectedPhase: 'DESCENDING',
    spacing: const Duration(milliseconds: 90),
  );
  await _driveUntilPhase(
    harness,
    peakPose,
    expectedPhase: 'PEAK',
    spacing: const Duration(milliseconds: 90),
  );
  await _driveUntilPhase(
    harness,
    returningPose,
    expectedPhase: 'ASCENDING',
    spacing: const Duration(milliseconds: 90),
  );
  await _driveUntilPhase(
    harness,
    completionPose ?? neutralPose,
    expectedPhase: 'NEUTRAL',
    spacing: const Duration(milliseconds: 120),
  );
}

Future<void> _establishHold(_ControllerHarness harness, Pose pose) async {
  await _analyzePose(harness, pose);
  harness.clock.advance(const Duration(milliseconds: 100));
  await _analyzePose(harness, pose);
  harness.clock.advance(const Duration(seconds: 3));
  await _analyzePose(harness, pose);
}

Future<void> _driveUntilPhase(
  _ControllerHarness harness,
  Pose pose, {
  required String expectedPhase,
  required Duration spacing,
  int maxFrames = 12,
}) async {
  for (var index = 0; index < maxFrames; index++) {
    await _analyzePose(harness, pose);
    if (harness.state.currentPhase == expectedPhase) {
      return;
    }
    if (index < maxFrames - 1) {
      harness.clock.advance(spacing);
    }
  }

  throw TestFailure(
    'Expected phase $expectedPhase, got ${harness.state.currentPhase}',
  );
}

Future<void> _pumpPose(
  _ControllerHarness harness,
  Pose pose, {
  required int count,
  required Duration spacing,
}) async {
  for (var index = 0; index < count; index++) {
    await _analyzePose(harness, pose);
    if (index < count - 1) {
      harness.clock.advance(spacing);
    }
  }
}

Future<void> _analyzePose(_ControllerHarness harness, Pose pose) {
  return analyzeFrame(harness.controller, harness.detector, <Pose>[pose]);
}

void _expectValidRangeRepCharacterization(
  _ControllerHarness harness, {
  required ExerciseType expectedExercise,
  required String? expectedSelectedSide,
}) {
  final state = harness.state;
  final diagnostics = harness.controller.diagnosticsSnapshot();
  final timingTrace = diagnostics.lastEndedRangeRepTimingTrace;

  expect(<String, Object?>{
    'exercise': diagnostics.exerciseType,
    'analysis_kind': state.analysisKind.name,
    'phase': state.currentPhase,
    'rep_count': state.repCount,
    'validation_status':
        state.calibrationMetrics.lastRangeRepValidationStatus,
    'validation_reasons':
        state.calibrationMetrics.lastRangeRepValidationReasons,
    'validated_count': state.calibrationMetrics.rangeRepValidatedCount,
    'low_confidence_count':
        state.calibrationMetrics.rangeRepLowConfidenceCount,
    'invalid_count': state.calibrationMetrics.rangeRepInvalidCount,
    'completed_phase_sequence':
        state.calibrationMetrics.lastRangeRepSummaryCompletedPhaseSequence,
    'selected_side': state.calibrationMetrics.selectedRangeRepSide,
    'timing_outcome': timingTrace?.outcome.name,
    'timing_transitions': timingTrace?.transitions
        .map((transition) => transition.type)
        .toList(growable: false),
  }, <String, Object?>{
    'exercise': expectedExercise.id,
    'analysis_kind': 'rangeRep',
    'phase': 'NEUTRAL',
    'rep_count': 1,
    'validation_status': 'valid',
    'validation_reasons': const <String>[],
    'validated_count': 1,
    'low_confidence_count': 0,
    'invalid_count': 0,
    'completed_phase_sequence': true,
    'selected_side': expectedSelectedSide,
    'timing_outcome': RangeRepTimingTraceOutcome.completed.name,
    'timing_transitions': const <String>[
      'startTowardPeak',
      'reachPeak',
      'startReturning',
      'completeRep',
    ],
  });
  expect(state.validatedRepEvent, isNotNull);
  expect(state.validatedRepEvent!.countsTowardReps, isTrue);
  expect(state.lastRepScore, inInclusiveRange(0.0, 100.0));
  expect(state.lastRepScore.isFinite, isTrue);
  expect(
    diagnostics.framePosePipelineTimings.conversion.sampleCount,
    0,
  );
  expect(
    diagnostics.framePosePipelineTimings.poseDetection.sampleCount,
    greaterThan(0),
  );
  expect(
    diagnostics.framePosePipelineTimings.candidateEvaluation.sampleCount,
    greaterThan(0),
  );
  expect(
    diagnostics.framePosePipelineTimings.total.sampleCount,
    greaterThan(0),
  );
}

void _expectHoldCharacterization(
  _ControllerHarness harness, {
  required ExerciseType expectedExercise,
}) {
  final state = harness.state;
  final diagnostics = harness.controller.diagnosticsSnapshot();

  expect(<String, Object?>{
    'exercise': diagnostics.exerciseType,
    'analysis_kind': state.analysisKind.name,
    'phase': state.currentPhase,
    'is_holding': state.isHolding,
    'current_hold_seconds': state.currentHoldSeconds,
    'best_hold_seconds': state.bestHoldSeconds,
    'feedback_code': state.holdFeedbackCode?.code,
    'engine_phase': state.holdEnginePhase?.code,
    'selected_side': state.selectedHoldSide?.name,
    'diagnostics_phase': diagnostics.currentPhase,
    'diagnostics_is_holding': diagnostics.isHolding,
  }, <String, Object?>{
    'exercise': expectedExercise.id,
    'analysis_kind': 'hold',
    'phase': 'HOLDING',
    'is_holding': true,
    'current_hold_seconds': 3.0,
    'best_hold_seconds': 3.0,
    'feedback_code': HoldFeedbackCode.holdPosition.code,
    'engine_phase': HoldPhase.holding.code,
    'selected_side': 'left',
    'diagnostics_phase': 'HOLDING',
    'diagnostics_is_holding': true,
  });
  expect(diagnostics.framePosePipelineTimings.poseDetection.sampleCount, 3);
  expect(diagnostics.framePosePipelineTimings.total.sampleCount, 3);
}

class _ControllerHarness {
  const _ControllerHarness({
    required this.container,
    required this.subscription,
    required this.controller,
    required this.detector,
    required this.clock,
  });

  final ProviderContainer container;
  final ProviderSubscription<WorkoutState> subscription;
  final WorkoutController controller;
  final TestQueuedPoseDetector detector;
  final TestFakeClock clock;

  WorkoutState get state => container.read(workoutControllerProvider);

  void dispose() {
    subscription.close();
    container.dispose();
  }
}
