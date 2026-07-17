import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_config.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_contract.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_side.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/range_rep_contract.dart';

void main() {
  group('ExerciseConfig.fromMap', () {
    test(
      'parses the squat asset config without changing range-rep semantics',
      () {
        final config = _loadConfig('assets/config/exercises/squat.json');

        expect(config.name, 'Squat');
        expect(config.primaryJoint, PoseLandmarkType.leftKnee);
        expect(config.joint1, PoseLandmarkType.leftHip);
        expect(config.joint2, PoseLandmarkType.leftAnkle);
        expect(config.rangeRepSignals, isNotNull);
        expect(config.usesLegacyRangeRepSignalFallback, isFalse);
        expect(
          config.rangeRepSignals
              ?.definitionFor(RangeRepSignal.postureAngle)
              ?.angle
              ?.first,
          PoseLandmarkType.leftShoulder,
        );
        expect(
          config.rangeRepSignals
              ?.definitionFor(RangeRepSignal.depthMetric)
              ?.source,
          RangeRepSignalSource.primaryMetric,
        );
        expect(
          config.rangeRepSignals
              ?.definitionFor(RangeRepSignal.endRangeMetric)
              ?.angle
              ?.last,
          PoseLandmarkType.leftAnkle,
        );
      },
    );

    test(
      'parses the push-up asset config without changing range-rep semantics',
      () {
        final config = _loadConfig('assets/config/exercises/push_up.json');

        expect(config.name, 'Push-Up');
        expect(config.primaryJoint, PoseLandmarkType.leftElbow);
        expect(config.joint1, PoseLandmarkType.leftShoulder);
        expect(config.joint2, PoseLandmarkType.leftWrist);
        expect(config.rangeRepSignals, isNotNull);
        expect(config.usesLegacyRangeRepSignalFallback, isFalse);
        expect(
          config.rangeRepSignals
              ?.definitionFor(RangeRepSignal.depthMetric)
              ?.source,
          RangeRepSignalSource.primaryMetric,
        );
        expect(
          config.rangeRepSignals
              ?.definitionFor(RangeRepSignal.postureAngle)
              ?.angle
              ?.middle,
          PoseLandmarkType.leftHip,
        );
        expect(
          config.rangeRepSignals
              ?.definitionFor(RangeRepSignal.alignmentMetric)
              ?.angle
              ?.last,
          PoseLandmarkType.leftAnkle,
        );
        expect(
          config.rangeRepSignals
              ?.definitionFor(RangeRepSignal.endRangeMetric)
              ?.angle
              ?.middle,
          PoseLandmarkType.leftElbow,
        );
      },
    );

    test('parses the sit-up asset config as a strict range-rep definition', () {
      final config = _loadConfig('assets/config/exercises/sit_up.json');

      expect(config.name, 'Sit-up');
      expect(config.primaryJoint, PoseLandmarkType.leftHip);
      expect(config.joint1, PoseLandmarkType.leftShoulder);
      expect(config.joint2, PoseLandmarkType.leftKnee);
      expect(config.thresholdNeutral, 120.0);
      expect(config.thresholdActive, 113.0);
      expect(config.thresholdPeak, 83.0);
      expect(config.formThreshold, 60.0);
      expect(config.targetMinAngle, 70.0);
      expect(config.rangeRepSignals, isNotNull);
      expect(config.usesLegacyRangeRepSignalFallback, isFalse);
      expect(
        config.rangeRepSignals
            ?.definitionFor(RangeRepSignal.postureAngle)
            ?.angle
            ?.first,
        PoseLandmarkType.leftHip,
      );
      expect(
        config.rangeRepSignals
            ?.definitionFor(RangeRepSignal.postureAngle)
            ?.angle
            ?.middle,
        PoseLandmarkType.leftKnee,
      );
      expect(
        config.rangeRepSignals
            ?.definitionFor(RangeRepSignal.postureAngle)
            ?.angle
            ?.last,
        PoseLandmarkType.leftAnkle,
      );
      expect(
        config.rangeRepSignals
            ?.definitionFor(RangeRepSignal.depthMetric)
            ?.source,
        RangeRepSignalSource.primaryMetric,
      );
      expect(
        config.rangeRepSignals
            ?.definitionFor(RangeRepSignal.postureAngle)
            ?.transform,
        RangeRepSignalTransform.identity,
      );
    });

    test(
      'parses the biceps curl asset config with complement180 posture form',
      () {
        final config = _loadConfig('assets/config/exercises/biceps_curl.json');

        expect(config.name, 'Biceps Curl');
        expect(config.primaryJoint, PoseLandmarkType.leftElbow);
        expect(config.joint1, PoseLandmarkType.leftShoulder);
        expect(config.joint2, PoseLandmarkType.leftWrist);
        expect(config.thresholdNeutral, 155.0);
        expect(config.thresholdActive, 140.0);
        expect(config.thresholdPeak, 88.0);
        expect(config.formThreshold, 150.0);
        expect(config.targetMinAngle, 75.0);
        expect(
          config.rangeRepSignals
              ?.definitionFor(RangeRepSignal.postureAngle)
              ?.transform,
          RangeRepSignalTransform.complement180,
        );
        expect(
          config.rangeRepSignals
              ?.definitionFor(RangeRepSignal.depthMetric)
              ?.transform,
          RangeRepSignalTransform.identity,
        );
        expect(
          config.rangeRepSignals
              ?.definitionFor(RangeRepSignal.depthMetric)
              ?.source,
          RangeRepSignalSource.primaryMetric,
        );
      },
    );

    test('parses the plank asset config without changing hold semantics', () {
      final config = _loadConfig('assets/config/exercises/plank.json');

      expect(config.name, 'Plank');
      expect(config.holdSignals, isNotNull);
      expect(config.holdSignals?.referenceSide, HoldSide.left);
      expect(
        config.holdSignals?.definitionFor(HoldSignal.alignment)?.middle,
        PoseLandmarkType.leftHip,
      );
      expect(
        config.holdSignals?.definitionFor(HoldSignal.support)?.middle,
        PoseLandmarkType.leftElbow,
      );
      expect(
        config.holdSignals?.definitionFor(HoldSignal.extension)?.last,
        PoseLandmarkType.leftAnkle,
      );
      expect(config.rangeRepSignals, isNull);
      expect(config.resolvedRangeRepSignals, isNull);
      expect(config.thresholdNeutral, 160.0);
      expect(config.thresholdActive, 168.0);
      expect(
        config.resolvedHoldPosture.breakGraceDuration,
        const Duration(milliseconds: 300),
      );
    });

    test(
      'parses the hollow hold asset config with typed Hollow posture semantics',
      () {
        final config = _loadConfig('assets/config/exercises/hollow_hold.json');

        expect(config.name, 'Hollow Hold');
        expect(config.holdSignals, isNotNull);
        expect(config.holdSignals?.referenceSide, HoldSide.left);
        expect(
          config.holdSignals?.definitionFor(HoldSignal.compression)?.middle,
          PoseLandmarkType.leftHip,
        );
        expect(
          config.holdSignals?.definitionFor(HoldSignal.armExtension)?.middle,
          PoseLandmarkType.leftShoulder,
        );
        expect(
          config.holdSignals?.definitionFor(HoldSignal.kneeExtension)?.middle,
          PoseLandmarkType.leftKnee,
        );
        expect(config.hollowHoldPosture, isNotNull);
        expect(config.hollowHoldPosture?.activePostureMaxAngle, 170.0);
        expect(config.hollowHoldPosture?.compressionEntryMaxAngle, 165.0);
        expect(config.hollowHoldPosture?.compressionSustainMaxAngle, 169.0);
        expect(config.hollowHoldPosture?.armExtensionMinAngle, 120.0);
        expect(config.hollowHoldPosture?.kneeExtensionMinAngle, 165.0);
        expect(
          config.hollowHoldPosture?.breakGraceDuration,
          const Duration(milliseconds: 300),
        );
        expect(config.thresholdNeutral, 170.0);
        expect(config.thresholdActive, 165.0);
        expect(config.rangeRepSignals, isNull);
      },
    );

    test('keeps legacy squat configs without rangeRepSignals valid', () {
      final config = ExerciseConfig.fromMap(<String, dynamic>{
        'name': 'Legacy Squat',
        'primaryJoint': 'leftKnee',
        'joint1': 'leftHip',
        'joint2': 'leftAnkle',
        'thresholdNeutral': 160.0,
        'thresholdActive': 150.0,
        'thresholdPeak': 95.0,
      });

      expect(config.rangeRepSignals, isNull);
      expect(config.usesLegacyRangeRepSignalFallback, isTrue);
      expect(
        config.resolvedRangeRepSignals?.definitionFor(
          RangeRepSignal.postureAngle,
        ),
        isNotNull,
      );
      expect(
        config.resolvedRangeRepSignals
            ?.definitionFor(RangeRepSignal.depthMetric)
            ?.source,
        RangeRepSignalSource.primaryMetric,
      );
    });
  });
}

ExerciseConfig _loadConfig(String path) {
  final json = jsonDecode(File(path).readAsStringSync());
  return ExerciseConfig.fromMap(Map<String, dynamic>.from(json as Map));
}
