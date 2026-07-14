import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/engine_kind.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_metrics.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/pose_quality_policy.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_config.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_contract.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/range_rep_contract.dart';

void main() {
  const policy = PoseQualityPolicy();

  group('PoseQualityPolicy', () {
    test('all required squat landmarks with high likelihood are accepted', () {
      final assessment = policy.assess(
        pose: _squatPose(),
        config: _legacySquatConfig(),
        engineKind: EngineKind.rangeRep,
        rangeRepContract: RangeRepContracts.squat,
      );

      expect(assessment.isAccepted, isTrue);
      expect(assessment.acceptedSide, isNotNull);
      expect(
        assessment.acceptedRangeRepSides,
        containsAll(<RangeRepSide>[RangeRepSide.left, RangeRepSide.right]),
      );
    });

    test('one required landmark below 0.50 is rejected', () {
      final assessment = policy.assess(
        pose: _squatPose(leftHipLikelihood: 0.49, includeRightSide: false),
        config: _legacySquatConfig(),
        engineKind: EngineKind.rangeRep,
        rangeRepContract: RangeRepContracts.squat,
      );

      expect(assessment.isAccepted, isFalse);
      expect(
        assessment.rejectionReason,
        PoseRejectionReason.lowLandmarkLikelihood,
      );
    });

    test('mean below 0.65 is rejected', () {
      final assessment = policy.assess(
        pose: _squatPose(
          defaultLikelihood: 0.60,
          leftHipLikelihood: 0.60,
          includeRightSide: false,
        ),
        config: _legacySquatConfig(),
        engineKind: EngineKind.rangeRep,
        rangeRepContract: RangeRepContracts.squat,
      );

      expect(assessment.isAccepted, isFalse);
      expect(assessment.rejectionReason, PoseRejectionReason.lowMeanLikelihood);
    });

    test('missing required landmark is rejected', () {
      final assessment = policy.assess(
        pose: _squatPose(includeLeftKnee: false, includeRightSide: false),
        config: _legacySquatConfig(),
        engineKind: EngineKind.rangeRep,
        rangeRepContract: RangeRepContracts.squat,
      );

      expect(assessment.isAccepted, isFalse);
      expect(
        assessment.rejectionReason,
        PoseRejectionReason.missingRequiredLandmark,
      );
    });

    test('NaN coordinate is rejected', () {
      final assessment = policy.assess(
        pose: _squatPose(leftHipX: double.nan, includeRightSide: false),
        config: _legacySquatConfig(),
        engineKind: EngineKind.rangeRep,
        rangeRepContract: RangeRepContracts.squat,
      );

      expect(assessment.isAccepted, isFalse);
      expect(
        assessment.rejectionReason,
        PoseRejectionReason.nonFiniteCoordinate,
      );
    });

    test('infinite coordinate is rejected', () {
      final assessment = policy.assess(
        pose: _squatPose(leftHipX: double.infinity, includeRightSide: false),
        config: _legacySquatConfig(),
        engineKind: EngineKind.rangeRep,
        rangeRepContract: RangeRepContracts.squat,
      );

      expect(assessment.isAccepted, isFalse);
      expect(
        assessment.rejectionReason,
        PoseRejectionReason.nonFiniteCoordinate,
      );
    });

    test('degenerate angle triplet is rejected', () {
      final assessment = policy.assess(
        pose: _squatPose(
          leftHipX: 0,
          leftHipY: 1,
          leftKneeX: 0,
          leftKneeY: 1,
          includeRightSide: false,
        ),
        config: _legacySquatConfig(),
        engineKind: EngineKind.rangeRep,
        rangeRepContract: RangeRepContracts.squat,
      );

      expect(assessment.isAccepted, isFalse);
      expect(
        assessment.rejectionReason,
        PoseRejectionReason.degenerateGeometry,
      );
    });

    test('squat valid left and unavailable right accepts left side', () {
      final assessment = policy.assess(
        pose: _squatPose(includeRightSide: false),
        config: _legacySquatConfig(),
        engineKind: EngineKind.rangeRep,
        rangeRepContract: RangeRepContracts.squat,
      );

      expect(assessment.isAccepted, isTrue);
      expect(assessment.acceptedSide?.name, 'left');
      expect(assessment.acceptedRangeRepSides, <RangeRepSide>{
        RangeRepSide.left,
      });
      expect(assessment.preferredRangeRepSide, RangeRepSide.left);
    });

    test('range-rep quality keeps both accepted sides and prefers the stronger '
        'one', () {
      final assessment = policy.assess(
        pose: _squatPose(
          defaultLikelihood: 0.80,
          leftHipLikelihood: 0.70,
          includeRightSide: true,
        ),
        config: _legacySquatConfig(),
        engineKind: EngineKind.rangeRep,
        rangeRepContract: RangeRepContracts.squat,
      );

      expect(assessment.isAccepted, isTrue);
      expect(assessment.acceptedRangeRepSides, <RangeRepSide>{
        RangeRepSide.left,
        RangeRepSide.right,
      });
      expect(assessment.preferredRangeRepSide, RangeRepSide.right);
    });

    test('push-up required landmark set is accepted', () {
      final assessment = policy.assess(
        pose: _pushUpPose(),
        config: _loadConfig('assets/config/exercises/push_up.json'),
        engineKind: EngineKind.rangeRep,
        rangeRepContract: RangeRepContracts.pushUp,
      );

      expect(assessment.isAccepted, isTrue);
    });

    test('plank valid required landmarks are accepted', () {
      final assessment = policy.assess(
        pose: _plankPose(),
        config: _plankConfig(),
        engineKind: EngineKind.hold,
        holdContract: HoldContracts.plankFamily,
      );

      expect(assessment.isAccepted, isTrue);
      expect(assessment.acceptedSide, isNull);
    });

    group('hold quality', () {
      for (final scenario in <({PoseLandmarkType landmark, String name})>[
        (landmark: PoseLandmarkType.leftShoulder, name: 'left shoulder'),
        (landmark: PoseLandmarkType.leftElbow, name: 'left elbow'),
        (landmark: PoseLandmarkType.leftWrist, name: 'left wrist'),
        (landmark: PoseLandmarkType.leftHip, name: 'left hip'),
        (landmark: PoseLandmarkType.leftKnee, name: 'left knee'),
        (landmark: PoseLandmarkType.leftAnkle, name: 'left ankle'),
      ]) {
        test('missing required hold landmark ${scenario.name} is rejected', () {
          final assessment = policy.assess(
            pose: _plankPose(
              missingLandmarks: <PoseLandmarkType>{scenario.landmark},
            ),
            config: _plankConfig(),
            engineKind: EngineKind.hold,
            holdContract: HoldContracts.plankFamily,
          );

          expect(assessment.isAccepted, isFalse);
          expect(
            assessment.rejectionReason,
            PoseRejectionReason.missingRequiredLandmark,
          );
        });
      }

      test('required hold landmark below 0.50 likelihood is rejected', () {
        final assessment = policy.assess(
          pose: _plankPose(
            likelihoodOverrides: const <PoseLandmarkType, double>{
              PoseLandmarkType.leftHip: 0.49,
            },
          ),
          config: _plankConfig(),
          engineKind: EngineKind.hold,
          holdContract: HoldContracts.plankFamily,
        );

        expect(assessment.isAccepted, isFalse);
        expect(
          assessment.rejectionReason,
          PoseRejectionReason.lowLandmarkLikelihood,
        );
      });

      test('mean required hold likelihood below 0.65 is rejected', () {
        final assessment = policy.assess(
          pose: _plankPose(defaultLikelihood: 0.60),
          config: _plankConfig(),
          engineKind: EngineKind.hold,
          holdContract: HoldContracts.plankFamily,
        );

        expect(assessment.isAccepted, isFalse);
        expect(
          assessment.rejectionReason,
          PoseRejectionReason.lowMeanLikelihood,
        );
      });

      test('non-finite required hold coordinate is rejected', () {
        final assessment = policy.assess(
          pose: _plankPose(
            coordinateOverrides: <PoseLandmarkType, _CoordinateOverride>{
              PoseLandmarkType.leftHip: const _CoordinateOverride(
                double.nan,
                0,
              ),
            },
          ),
          config: _plankConfig(),
          engineKind: EngineKind.hold,
          holdContract: HoldContracts.plankFamily,
        );

        expect(assessment.isAccepted, isFalse);
        expect(
          assessment.rejectionReason,
          PoseRejectionReason.nonFiniteCoordinate,
        );
      });

      for (final scenario
          in <
            ({
              String name,
              Map<PoseLandmarkType, _CoordinateOverride> overrides,
            })
          >[
            (
              name: 'degenerate body-line triplet is rejected',
              overrides: <PoseLandmarkType, _CoordinateOverride>{
                PoseLandmarkType.leftHip: const _CoordinateOverride(-1, 0),
              },
            ),
            (
              name: 'degenerate arm-support triplet is rejected',
              overrides: <PoseLandmarkType, _CoordinateOverride>{
                PoseLandmarkType.leftElbow: const _CoordinateOverride(-1, 0),
              },
            ),
            (
              name: 'degenerate leg-extension triplet is rejected',
              overrides: <PoseLandmarkType, _CoordinateOverride>{
                PoseLandmarkType.leftKnee: const _CoordinateOverride(0, 0),
              },
            ),
          ]) {
        test(scenario.name, () {
          final assessment = policy.assess(
            pose: _plankPose(coordinateOverrides: scenario.overrides),
            config: _plankConfig(),
            engineKind: EngineKind.hold,
            holdContract: HoldContracts.plankFamily,
          );

          expect(assessment.isAccepted, isFalse);
          expect(
            assessment.rejectionReason,
            PoseRejectionReason.degenerateGeometry,
          );
        });
      }

      test('current hold quality rejects a right-only pose', () {
        final assessment = policy.assess(
          pose: _plankPose(rightOnly: true),
          config: _plankConfig(),
          engineKind: EngineKind.hold,
          holdContract: HoldContracts.plankFamily,
        );

        expect(assessment.isAccepted, isFalse);
        expect(
          assessment.rejectionReason,
          PoseRejectionReason.missingRequiredLandmark,
        );
        expect(assessment.acceptedSide, isNull);
      });

      test(
        'hold quality uses config-driven requirements for test-only signal geometry',
        () {
          final assessment = policy.assess(
            pose: _alternateHoldPose(),
            config: _alternateHoldConfig(),
            engineKind: EngineKind.hold,
            holdContract: HoldContracts.plankFamily,
          );

          expect(assessment.isAccepted, isTrue);
          expect(assessment.acceptedSide, isNull);
          expect(assessment.requiredLandmarkCount, 7);
        },
      );
    });
  });
}

ExerciseConfig _loadConfig(String path) {
  final rawJson = File(path).readAsStringSync();
  return ExerciseConfig.fromMap(jsonDecode(rawJson) as Map<String, dynamic>);
}

ExerciseConfig _legacySquatConfig() {
  return ExerciseConfig(
    name: 'Squat',
    primaryJoint: PoseLandmarkType.leftKnee,
    joint1: PoseLandmarkType.leftHip,
    joint2: PoseLandmarkType.leftAnkle,
    thresholdNeutral: 160,
    thresholdActive: 150,
    thresholdPeak: 95,
    formThreshold: 45,
    targetMinAngle: 70,
  );
}

ExerciseConfig _plankConfig() {
  return ExerciseConfig(
    name: 'Plank',
    primaryJoint: PoseLandmarkType.leftHip,
    joint1: PoseLandmarkType.leftShoulder,
    joint2: PoseLandmarkType.leftAnkle,
    thresholdNeutral: 160,
    thresholdActive: 168,
    thresholdPeak: 0,
    holdPosture: const HoldPostureConfig(
      activePostureAngle: 160,
      bodyLineEntryAngle: 168,
      bodyLineSustainAngle: 166,
      armSupportMinAngle: 60,
      armSupportMaxAngle: 120,
      legExtensionMinAngle: 165,
      breakGraceDuration: Duration(milliseconds: 300),
    ),
    holdSignals: const HoldSignalExtractionConfig(
      alignment: HoldAngleSignalConfig(
        first: PoseLandmarkType.leftShoulder,
        middle: PoseLandmarkType.leftHip,
        last: PoseLandmarkType.leftAnkle,
      ),
      support: HoldAngleSignalConfig(
        first: PoseLandmarkType.leftShoulder,
        middle: PoseLandmarkType.leftElbow,
        last: PoseLandmarkType.leftWrist,
      ),
      extension: HoldAngleSignalConfig(
        first: PoseLandmarkType.leftHip,
        middle: PoseLandmarkType.leftKnee,
        last: PoseLandmarkType.leftAnkle,
      ),
    ),
  );
}

ExerciseConfig _alternateHoldConfig() {
  return ExerciseConfig(
    name: 'Plank',
    primaryJoint: PoseLandmarkType.leftHip,
    joint1: PoseLandmarkType.leftShoulder,
    joint2: PoseLandmarkType.leftAnkle,
    thresholdNeutral: 160,
    thresholdActive: 168,
    thresholdPeak: 0,
    holdPosture: const HoldPostureConfig(
      activePostureAngle: 160,
      bodyLineEntryAngle: 168,
      bodyLineSustainAngle: 166,
      armSupportMinAngle: 60,
      armSupportMaxAngle: 120,
      legExtensionMinAngle: 165,
      breakGraceDuration: Duration(milliseconds: 300),
    ),
    holdSignals: const HoldSignalExtractionConfig(
      alignment: HoldAngleSignalConfig(
        first: PoseLandmarkType.leftShoulder,
        middle: PoseLandmarkType.leftHip,
        last: PoseLandmarkType.rightHip,
      ),
      support: HoldAngleSignalConfig(
        first: PoseLandmarkType.leftHip,
        middle: PoseLandmarkType.leftElbow,
        last: PoseLandmarkType.leftWrist,
      ),
      extension: HoldAngleSignalConfig(
        first: PoseLandmarkType.leftShoulder,
        middle: PoseLandmarkType.leftKnee,
        last: PoseLandmarkType.leftAnkle,
      ),
    ),
  );
}

Pose _squatPose({
  bool includeLeftKnee = true,
  bool includeRightSide = true,
  double defaultLikelihood = 0.95,
  double leftHipLikelihood = 0.95,
  double leftHipX = 0,
  double leftHipY = 1,
  double leftKneeX = 1,
  double leftKneeY = 1,
}) {
  return Pose(
    landmarks: <PoseLandmarkType, PoseLandmark>{
      PoseLandmarkType.leftShoulder: _landmark(
        PoseLandmarkType.leftShoulder,
        0,
        2,
        likelihood: defaultLikelihood,
      ),
      PoseLandmarkType.leftHip: _landmark(
        PoseLandmarkType.leftHip,
        leftHipX,
        leftHipY,
        likelihood: leftHipLikelihood,
      ),
      if (includeLeftKnee)
        PoseLandmarkType.leftKnee: _landmark(
          PoseLandmarkType.leftKnee,
          leftKneeX,
          leftKneeY,
          likelihood: defaultLikelihood,
        ),
      PoseLandmarkType.leftAnkle: _landmark(
        PoseLandmarkType.leftAnkle,
        1,
        0,
        likelihood: defaultLikelihood,
      ),
      if (includeRightSide) ...<PoseLandmarkType, PoseLandmark>{
        PoseLandmarkType.rightShoulder: _landmark(
          PoseLandmarkType.rightShoulder,
          4,
          2,
          likelihood: defaultLikelihood,
        ),
        PoseLandmarkType.rightHip: _landmark(
          PoseLandmarkType.rightHip,
          4,
          1,
          likelihood: defaultLikelihood,
        ),
        PoseLandmarkType.rightKnee: _landmark(
          PoseLandmarkType.rightKnee,
          3,
          1,
          likelihood: defaultLikelihood,
        ),
        PoseLandmarkType.rightAnkle: _landmark(
          PoseLandmarkType.rightAnkle,
          3,
          0,
          likelihood: defaultLikelihood,
        ),
      },
    },
  );
}

Pose _pushUpPose() {
  return Pose(
    landmarks: <PoseLandmarkType, PoseLandmark>{
      PoseLandmarkType.leftShoulder: _landmark(
        PoseLandmarkType.leftShoulder,
        0,
        2,
      ),
      PoseLandmarkType.leftElbow: _landmark(PoseLandmarkType.leftElbow, 1, 2),
      PoseLandmarkType.leftWrist: _landmark(PoseLandmarkType.leftWrist, 1, 1),
      PoseLandmarkType.leftHip: _landmark(PoseLandmarkType.leftHip, 2, 2),
      PoseLandmarkType.leftAnkle: _landmark(PoseLandmarkType.leftAnkle, 4, 2),
    },
  );
}

Pose _plankPose({
  double defaultLikelihood = 0.95,
  Map<PoseLandmarkType, double> likelihoodOverrides =
      const <PoseLandmarkType, double>{},
  Map<PoseLandmarkType, _CoordinateOverride> coordinateOverrides =
      const <PoseLandmarkType, _CoordinateOverride>{},
  Set<PoseLandmarkType> missingLandmarks = const <PoseLandmarkType>{},
  bool rightOnly = false,
}) {
  final landmarks = <PoseLandmarkType, PoseLandmark>{};

  void addLandmark(PoseLandmarkType type, double x, double y) {
    if (missingLandmarks.contains(type)) {
      return;
    }
    final override = coordinateOverrides[type];
    landmarks[type] = _landmark(
      type,
      override?.x ?? x,
      override?.y ?? y,
      likelihood: likelihoodOverrides[type] ?? defaultLikelihood,
    );
  }

  if (rightOnly) {
    addLandmark(PoseLandmarkType.rightShoulder, 1, 0);
    addLandmark(PoseLandmarkType.rightElbow, 0.5, 0);
    addLandmark(PoseLandmarkType.rightWrist, 0.5, -1);
    addLandmark(PoseLandmarkType.rightHip, 0, 0);
    addLandmark(PoseLandmarkType.rightKnee, -0.5, 0);
    addLandmark(PoseLandmarkType.rightAnkle, -1, 0);
  } else {
    addLandmark(PoseLandmarkType.leftShoulder, -1, 0);
    addLandmark(PoseLandmarkType.leftElbow, -0.5, 0);
    addLandmark(PoseLandmarkType.leftWrist, -0.5, -1);
    addLandmark(PoseLandmarkType.leftHip, 0, 0);
    addLandmark(PoseLandmarkType.leftKnee, 0.5, 0);
    addLandmark(PoseLandmarkType.leftAnkle, 1, 0);
  }

  return Pose(landmarks: landmarks);
}

Pose _alternateHoldPose({double defaultLikelihood = 0.95}) {
  return Pose(
    landmarks: <PoseLandmarkType, PoseLandmark>{
      PoseLandmarkType.leftShoulder: _landmark(
        PoseLandmarkType.leftShoulder,
        0,
        1,
        likelihood: defaultLikelihood,
      ),
      PoseLandmarkType.leftHip: _landmark(
        PoseLandmarkType.leftHip,
        0,
        0,
        likelihood: defaultLikelihood,
      ),
      PoseLandmarkType.rightHip: _landmark(
        PoseLandmarkType.rightHip,
        1,
        0,
        likelihood: defaultLikelihood,
      ),
      PoseLandmarkType.leftElbow: _landmark(
        PoseLandmarkType.leftElbow,
        1,
        0,
        likelihood: defaultLikelihood,
      ),
      PoseLandmarkType.leftWrist: _landmark(
        PoseLandmarkType.leftWrist,
        1,
        1,
        likelihood: defaultLikelihood,
      ),
      PoseLandmarkType.leftKnee: _landmark(
        PoseLandmarkType.leftKnee,
        1,
        0,
        likelihood: defaultLikelihood,
      ),
      PoseLandmarkType.leftAnkle: _landmark(
        PoseLandmarkType.leftAnkle,
        2,
        -1,
        likelihood: defaultLikelihood,
      ),
    },
  );
}

PoseLandmark _landmark(
  PoseLandmarkType type,
  double x,
  double y, {
  double likelihood = 0.95,
}) {
  return PoseLandmark(type: type, x: x, y: y, z: 0, likelihood: likelihood);
}

class _CoordinateOverride {
  const _CoordinateOverride(this.x, this.y);

  final double x;
  final double y;
}
