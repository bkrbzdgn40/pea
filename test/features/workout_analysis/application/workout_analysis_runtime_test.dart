import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/common_frame_pose_pipeline.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/engine_kind.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/hold_coordinator.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/pose_acceptance_stabilizer.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/range_rep_coordinator.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/workout_analysis_runtime.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/hold_analysis_engine.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_config.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_contract.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/range_rep_contract.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_type.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/range_rep_analysis_engine.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/range_rep_validation_policy.dart';

import '../../../support/workout_analysis_test_support.dart';

void main() {
  test('assembles the complete range-rep runtime graph', () {
    final clock = TestFakeClock();
    var frameFactoryCalls = 0;
    var rangeFactoryCalls = 0;
    var holdFactoryCalls = 0;

    final runtime = const WorkoutAnalysisRuntimeFactory().create(
      activeExercise: ExerciseType.squat,
      config: buildSquatConfig(),
      clock: clock.now,
      framePosePipelineFactory:
          ({required PoseAcceptanceStabilizer poseAcceptanceStabilizer}) {
            frameFactoryCalls++;
            return WorkoutFramePosePipeline(
              poseAcceptanceStabilizer: poseAcceptanceStabilizer,
            );
          },
      rangeRepCoordinatorFactory:
          ({
            required RangeRepAnalysisEngine engine,
            required ExerciseConfig config,
            required RangeRepContract rangeRepContract,
            required RangeRepValidationConfig rangeRepValidationConfig,
          }) {
            rangeFactoryCalls++;
            return DefaultRangeRepCoordinator(
              engine: engine,
              config: config,
              rangeRepContract: rangeRepContract,
              rangeRepValidationConfig: rangeRepValidationConfig,
            );
          },
      holdCoordinatorFactory:
          ({
            required HoldAnalysisEngine engine,
            required ExerciseConfig config,
            required HoldContract holdContract,
          }) {
            holdFactoryCalls++;
            return DefaultHoldCoordinator(
              engine: engine,
              config: config,
              holdContract: holdContract,
            );
          },
      diagnosticsEnabled: true,
    );

    expect(runtime.engineKind, EngineKind.rangeRep);
    expect(runtime.activeExercise, ExerciseType.squat);
    expect(runtime.rangeRepContract, isNotNull);
    expect(runtime.holdContract, isNull);
    expect(runtime.rangeRepEngine, isNotNull);
    expect(runtime.rangeRepCoordinator, isNotNull);
    expect(runtime.primaryMetricNormalizer, isNotNull);
    expect(runtime.rangeRepTemporalContinuityTracker, isNotNull);
    expect(runtime.holdCoordinator, isNull);
    expect(runtime.diagnosticsReporter.enabled, isTrue);
    expect(runtime.fpsWindowStartedAt, clock.now());
    expect(frameFactoryCalls, 1);
    expect(rangeFactoryCalls, 1);
    expect(holdFactoryCalls, 0);
  });

  test('assembles the complete hold runtime graph', () {
    final clock = TestFakeClock();
    var rangeFactoryCalls = 0;
    var holdFactoryCalls = 0;

    final runtime = const WorkoutAnalysisRuntimeFactory().create(
      activeExercise: ExerciseType.plank,
      config: buildPlankConfig(),
      clock: clock.now,
      framePosePipelineFactory:
          ({required PoseAcceptanceStabilizer poseAcceptanceStabilizer}) {
            return WorkoutFramePosePipeline(
              poseAcceptanceStabilizer: poseAcceptanceStabilizer,
            );
          },
      rangeRepCoordinatorFactory:
          ({
            required RangeRepAnalysisEngine engine,
            required ExerciseConfig config,
            required RangeRepContract rangeRepContract,
            required RangeRepValidationConfig rangeRepValidationConfig,
          }) {
            rangeFactoryCalls++;
            return DefaultRangeRepCoordinator(
              engine: engine,
              config: config,
              rangeRepContract: rangeRepContract,
              rangeRepValidationConfig: rangeRepValidationConfig,
            );
          },
      holdCoordinatorFactory:
          ({
            required HoldAnalysisEngine engine,
            required ExerciseConfig config,
            required HoldContract holdContract,
          }) {
            holdFactoryCalls++;
            return DefaultHoldCoordinator(
              engine: engine,
              config: config,
              holdContract: holdContract,
            );
          },
      diagnosticsEnabled: false,
    );

    expect(runtime.engineKind, EngineKind.hold);
    expect(runtime.activeExercise, ExerciseType.plank);
    expect(runtime.rangeRepContract, isNull);
    expect(runtime.holdContract, isNotNull);
    expect(runtime.rangeRepEngine, isNull);
    expect(runtime.rangeRepCoordinator, isNull);
    expect(runtime.primaryMetricNormalizer, isNull);
    expect(runtime.rangeRepTemporalContinuityTracker, isNull);
    expect(runtime.holdCoordinator, isNotNull);
    expect(runtime.diagnosticsReporter.enabled, isFalse);
    expect(rangeFactoryCalls, 0);
    expect(holdFactoryCalls, 1);
  });
}
