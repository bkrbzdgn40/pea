import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/engine_kind.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_landmark_requirements.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_metrics.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_metrics_extractor.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/pose_quality_policy.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/prepared_exercise_analysis_context.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_config.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_contract.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_side.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/range_rep_contract.dart';

import '../../../support/workout_analysis_test_support.dart';

void main() {
  group('PreparedExerciseAnalysisContext', () {
    test(
      'reuses unilateral requirements across quality and metrics frames',
      () {
        final requirements = _CountingExerciseLandmarkRequirements();
        final config = loadExerciseConfig('assets/config/exercises/squat.json');
        final context = PreparedExerciseAnalysisContext.resolve(
          config: config,
          engineKind: EngineKind.rangeRep,
          rangeRepContract: RangeRepContracts.squat,
          requirements: requirements,
        );
        final policy = PoseQualityPolicy(requirements: requirements);
        final extractor = ExerciseMetricsExtractor(requirements: requirements);
        final pose = buildSquatPose(angle: 90);

        expect(requirements.resolveCount, 2);

        for (var index = 0; index < 2; index++) {
          final assessment = policy.assessPrepared(
            pose: pose,
            config: config,
            preparedContext: context,
          );
          final metrics = extractor.extract(
            pose,
            config,
            engineKind: EngineKind.rangeRep,
            rangeRepContract: RangeRepContracts.squat,
            preparedContext: context,
          );

          expect(assessment.isAccepted, isTrue);
          expect(metrics.leftRangeRepMetrics.hasPrimaryAngle, isTrue);
        }

        expect(requirements.resolveCount, 2);
      },
    );

    test('prepares side and combined sets once for bilateral range-rep', () {
      final requirements = _CountingExerciseLandmarkRequirements();
      final config = loadExerciseConfig(
        'assets/config/exercises/biceps_curl.json',
      );

      final context = PreparedExerciseAnalysisContext.resolve(
        config: config,
        engineKind: EngineKind.rangeRep,
        rangeRepContract: RangeRepContracts.bicepsCurl,
        requirements: requirements,
      );

      expect(requirements.resolveCount, 3);
      expect(
        context.bilateralRangeRepPoseAcceptanceOrThrow().requiredLandmarks,
        isNotEmpty,
      );
    });

    test('prepares hold requirements once per side', () {
      final requirements = _CountingExerciseLandmarkRequirements();
      final context = PreparedExerciseAnalysisContext.resolve(
        config: buildPlankConfig(),
        engineKind: EngineKind.hold,
        holdContract: HoldContracts.plankFamily,
        requirements: requirements,
      );

      expect(requirements.resolveCount, 2);
      expect(
        context.holdPoseAcceptanceFor(HoldSide.left).requiredLandmarks,
        isNotEmpty,
      );
      expect(
        context.holdPoseAcceptanceFor(HoldSide.right).requiredLandmarks,
        isNotEmpty,
      );
    });
  });
}

class _CountingExerciseLandmarkRequirements
    extends ExerciseLandmarkRequirements {
  _CountingExerciseLandmarkRequirements();

  int resolveCount = 0;

  @override
  ExerciseLandmarkRequirementSet resolve({
    required ExerciseConfig config,
    required EngineKind engineKind,
    RangeRepContract? rangeRepContract,
    RangeRepSignalSet rangeRepSignalSet = RangeRepSignalSet.supportedAnalysis,
    HoldContract? holdContract,
    RangeRepSide? side,
    HoldSide? holdSide,
  }) {
    resolveCount++;
    return super.resolve(
      config: config,
      engineKind: engineKind,
      rangeRepContract: rangeRepContract,
      rangeRepSignalSet: rangeRepSignalSet,
      holdContract: holdContract,
      side: side,
      holdSide: holdSide,
    );
  }
}
