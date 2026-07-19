import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/engine_kind.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_landmark_requirements.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_metrics.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_metrics_extractor.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_config.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/range_rep_contract.dart';

import '../../../support/workout_analysis_test_support.dart';

void main() {
  const extractor = ExerciseMetricsExtractor();
  const requirements = ExerciseLandmarkRequirements();
  final config = _loadConfig('assets/config/exercises/sit_up.json');

  test(
    'Sit-up alone declares image-plane inclination as its primary metric',
    () {
      expect(
        RangeRepContracts.sitUp.primaryMetricKind,
        RangeRepPrimaryMetricKind.imagePlaneInclination,
      );
      expect(
        RangeRepContracts.squat.primaryMetricKind,
        RangeRepPrimaryMetricKind.jointAngle,
      );
      expect(
        RangeRepContracts.pushUp.primaryMetricKind,
        RangeRepPrimaryMetricKind.jointAngle,
      );
      expect(
        RangeRepContracts.bicepsCurl.primaryMetricKind,
        RangeRepPrimaryMetricKind.jointAngle,
      );
    },
  );

  test('Sit-up primary metric follows shoulder-to-hip torso orientation', () {
    final metrics = extractor.extract(
      _sitUpPose(torsoAngle: 125, kneeAngle: 120),
      config,
      engineKind: EngineKind.rangeRep,
      rangeRepContract: RangeRepContracts.sitUp,
    );

    expect(metrics.leftRangeRepMetrics.hasPrimaryAngle, isTrue);
    expect(metrics.leftRangeRepMetrics.primaryAngle, closeTo(125, 0.001));
    expect(
      metrics.leftRangeRepMetrics.formSignals?.depthMetric,
      closeTo(125, 0.001),
    );
  });

  test(
    'changing knee setup does not change Sit-up primary detection metric',
    () {
      final first = extractor.extract(
        _sitUpPose(torsoAngle: 108, kneeAngle: 120),
        config,
        engineKind: EngineKind.rangeRep,
        rangeRepContract: RangeRepContracts.sitUp,
      );
      final second = extractor.extract(
        _sitUpPose(torsoAngle: 108, kneeAngle: 45),
        config,
        engineKind: EngineKind.rangeRep,
        rangeRepContract: RangeRepContracts.sitUp,
      );

      expect(
        first.leftRangeRepMetrics.primaryAngle,
        closeTo(second.leftRangeRepMetrics.primaryAngle, 0.001),
      );
      expect(
        first.leftRangeRepMetrics.formMetric,
        isNot(closeTo(second.leftRangeRepMetrics.formMetric, 0.001)),
      );
    },
  );

  test('missing knee setup landmark does not remove Sit-up primary metric', () {
    final metrics = extractor.extract(
      _sitUpPose(
        torsoAngle: 82,
        kneeAngle: 120,
        missingLandmarks: const <PoseLandmarkType>{
          PoseLandmarkType.leftAnkle,
        },
      ),
      config,
      engineKind: EngineKind.rangeRep,
      rangeRepContract: RangeRepContracts.sitUp,
    );

    expect(metrics.leftRangeRepMetrics.hasPrimaryAngle, isTrue);
    expect(metrics.leftRangeRepMetrics.primaryAngle, closeTo(82, 0.001));
    expect(metrics.leftRangeRepMetrics.hasFormMetric, isFalse);
  });

  test(
    'Sit-up pose acceptance primary requirements use shoulder and hip only',
    () {
      final requirementSet = requirements.resolve(
        config: config,
        engineKind: EngineKind.rangeRep,
        rangeRepContract: RangeRepContracts.sitUp,
        rangeRepSignalSet: RangeRepSignalSet.poseAcceptanceRequired,
        side: RangeRepSide.left,
      );

      expect(
        requirementSet.requiredLandmarks,
        <PoseLandmarkType>{
          PoseLandmarkType.leftShoulder,
          PoseLandmarkType.leftHip,
        },
      );
      expect(requirementSet.requiredAngleTriplets, isEmpty);
      expect(requirementSet.requiredSegments, hasLength(1));
      expect(
        requirementSet.requiredSegments.single.first,
        PoseLandmarkType.leftShoulder,
      );
      expect(
        requirementSet.requiredSegments.single.second,
        PoseLandmarkType.leftHip,
      );
    },
  );
}

ExerciseConfig _loadConfig(String path) {
  return ExerciseConfig.fromMap(
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>,
  );
}

Pose _sitUpPose({
  required double torsoAngle,
  required double kneeAngle,
  Set<PoseLandmarkType> missingLandmarks = const <PoseLandmarkType>{},
}) {
  final torsoRadians = torsoAngle * math.pi / 180.0;
  final kneeRadians = kneeAngle * math.pi / 180.0;
  final landmarks = <PoseLandmarkType, PoseLandmark>{};

  void add(PoseLandmarkType type, double x, double y) {
    if (!missingLandmarks.contains(type)) {
      landmarks[type] = buildLandmark(type, x, y, likelihood: 0.95);
    }
  }

  add(PoseLandmarkType.leftHip, 0, 0);
  add(
    PoseLandmarkType.leftShoulder,
    math.cos(torsoRadians),
    math.sin(torsoRadians),
  );
  add(PoseLandmarkType.leftKnee, 1, 0);
  add(
    PoseLandmarkType.leftAnkle,
    1 - math.cos(kneeRadians),
    math.sin(kneeRadians),
  );

  return Pose(landmarks: landmarks);
}
