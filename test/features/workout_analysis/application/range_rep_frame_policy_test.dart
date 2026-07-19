import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/engine_kind.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_metrics.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_metrics_extractor.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/pose_quality_policy.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/range_rep_frame_policy.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/range_rep_side_policy.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/range_rep_contract.dart';

import '../../../support/workout_analysis_test_support.dart';

void main() {
  const extractor = ExerciseMetricsExtractor();
  const sidePolicy = RangeRepSidePolicy();
  const framePolicy = RangeRepFramePolicy();
  const poseQualityPolicy = PoseQualityPolicy();
  final sitUpConfig = loadExerciseConfig('assets/config/exercises/sit_up.json');
  final squatConfig = loadExerciseConfig('assets/config/exercises/squat.json');

  test(
    'sit-up low-likelihood ankle alone does not invalidate the production frame',
    () {
      final pose = buildSitUpPose(
        primaryAngle: 90,
        formAngle: 120,
        includeRightSide: false,
        likelihoodOverrides: const <PoseLandmarkType, double>{
          PoseLandmarkType.leftAnkle: 0.10,
        },
      );

      final qualityAssessment = poseQualityPolicy.assess(
        pose: pose,
        config: sitUpConfig,
        engineKind: EngineKind.rangeRep,
        rangeRepContract: RangeRepContracts.sitUp,
      );
      final metrics = extractor.extract(
        pose,
        sitUpConfig,
        engineKind: EngineKind.rangeRep,
        rangeRepContract: RangeRepContracts.sitUp,
      );
      final selection = sidePolicy.select(metrics: metrics);
      final frameAssessment = framePolicy.assessWithContract(
        metrics: metrics,
        selection: selection,
        contract: RangeRepContracts.sitUp,
      );

      expect(qualityAssessment.isAccepted, isTrue);
      expect(selection.selectedSide, RangeRepSide.left);
      expect(frameAssessment.isValid, isTrue);
      expect(frameAssessment.invalidReason, isNull);
      expect(frameAssessment.hasPrimaryAngle, isTrue);
      expect(frameAssessment.hasFormMetric, isTrue);
    },
  );

  test(
    'sit-up missing setup landmarks does not block an otherwise valid frame',
    () {
      final pose = buildSitUpPose(
        primaryAngle: 90,
        formAngle: 120,
        includeRightSide: false,
        missingLandmarks: const <PoseLandmarkType>{PoseLandmarkType.leftAnkle},
      );

      final qualityAssessment = poseQualityPolicy.assess(
        pose: pose,
        config: sitUpConfig,
        engineKind: EngineKind.rangeRep,
        rangeRepContract: RangeRepContracts.sitUp,
      );
      final metrics = extractor.extract(
        pose,
        sitUpConfig,
        engineKind: EngineKind.rangeRep,
        rangeRepContract: RangeRepContracts.sitUp,
      );
      final selection = sidePolicy.select(metrics: metrics);
      final frameAssessment = framePolicy.assessWithContract(
        metrics: metrics,
        selection: selection,
        contract: RangeRepContracts.sitUp,
      );

      expect(qualityAssessment.isAccepted, isTrue);
      expect(selection.selectedSide, RangeRepSide.left);
      expect(frameAssessment.isValid, isTrue);
      expect(frameAssessment.invalidReason, isNull);
      expect(frameAssessment.hasPrimaryAngle, isTrue);
      expect(frameAssessment.hasFormMetric, isFalse);
      expect(frameAssessment.feedbackMessage, isEmpty);
    },
  );

  test('squat still requires its pose-acceptance form metric', () {
    final pose = buildSquatPose(
      angle: 120,
      missingLandmarks: const <PoseLandmarkType>{PoseLandmarkType.leftShoulder},
    );
    final metrics = extractor.extract(
      pose,
      squatConfig,
      engineKind: EngineKind.rangeRep,
      rangeRepContract: RangeRepContracts.squat,
    );
    final selection = sidePolicy.select(metrics: metrics);
    final frameAssessment = framePolicy.assessWithContract(
      metrics: metrics,
      selection: selection,
      contract: RangeRepContracts.squat,
    );

    expect(selection.selectedSide, RangeRepSide.left);
    expect(frameAssessment.isValid, isFalse);
    expect(
      frameAssessment.invalidReason,
      RangeRepFrameInvalidReason.missingFormMetric,
    );
    expect(frameAssessment.hasPrimaryAngle, isTrue);
    expect(frameAssessment.hasFormMetric, isFalse);
  });
}
