import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/engine_kind.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_landmark_requirements.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_config.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_contract.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_side.dart';

void main() {
  const requirements = ExerciseLandmarkRequirements();

  group('ExerciseLandmarkRequirements hold resolution', () {
    test('hold resolves the exact required landmark set', () {
      final requirementSet = requirements.resolve(
        config: _holdConfig(),
        engineKind: EngineKind.hold,
        holdContract: HoldContracts.plankFamily,
        holdSide: HoldSide.left,
      );

      expect(requirementSet.requiredLandmarks, <PoseLandmarkType>{
        PoseLandmarkType.leftShoulder,
        PoseLandmarkType.leftElbow,
        PoseLandmarkType.leftWrist,
        PoseLandmarkType.leftHip,
        PoseLandmarkType.leftKnee,
        PoseLandmarkType.leftAnkle,
      });
    });

    test('hold resolves the exact angle triplets', () {
      final requirementSet = requirements.resolve(
        config: _holdConfig(),
        engineKind: EngineKind.hold,
        holdContract: HoldContracts.plankFamily,
        holdSide: HoldSide.left,
      );

      expect(
        requirementSet.requiredAngleTriplets.map(_tripletKey),
        unorderedEquals(<String>{
          'leftShoulder->leftHip->leftAnkle',
          'leftShoulder->leftElbow->leftWrist',
          'leftHip->leftKnee->leftAnkle',
        }),
      );
    });

    test('hold resolves the exact required segments', () {
      final requirementSet = requirements.resolve(
        config: _holdConfig(),
        engineKind: EngineKind.hold,
        holdContract: HoldContracts.plankFamily,
        holdSide: HoldSide.left,
      );

      expect(
        requirementSet.requiredSegments.map(_segmentKey),
        unorderedEquals(<String>{
          'leftShoulder->leftHip',
          'leftHip->leftAnkle',
          'leftShoulder->leftElbow',
          'leftElbow->leftWrist',
          'leftHip->leftKnee',
          'leftKnee->leftAnkle',
        }),
      );
    });

    test('hold resolves the mirrored right-side landmark set', () {
      final requirementSet = requirements.resolve(
        config: _holdConfig(),
        engineKind: EngineKind.hold,
        holdContract: HoldContracts.plankFamily,
        holdSide: HoldSide.right,
      );

      expect(requirementSet.requiredLandmarks, <PoseLandmarkType>{
        PoseLandmarkType.rightShoulder,
        PoseLandmarkType.rightElbow,
        PoseLandmarkType.rightWrist,
        PoseLandmarkType.rightHip,
        PoseLandmarkType.rightKnee,
        PoseLandmarkType.rightAnkle,
      });
      expect(
        requirementSet.requiredAngleTriplets.map(_tripletKey),
        unorderedEquals(<String>{
          'rightShoulder->rightHip->rightAnkle',
          'rightShoulder->rightElbow->rightWrist',
          'rightHip->rightKnee->rightAnkle',
        }),
      );
    });

    test(
      'hold requirements follow configured signal geometry instead of hardcoded plank triplets',
      () {
        final requirementSet = requirements.resolve(
          config: _alternateHoldConfig(),
          engineKind: EngineKind.hold,
          holdContract: HoldContracts.plankFamily,
          holdSide: HoldSide.left,
        );

        expect(
          requirementSet.requiredAngleTriplets.map(_tripletKey),
          unorderedEquals(<String>{
            'leftShoulder->leftHip->rightHip',
            'leftHip->leftElbow->leftWrist',
            'leftShoulder->leftKnee->leftAnkle',
          }),
        );
        expect(requirementSet.requiredLandmarks, <PoseLandmarkType>{
          PoseLandmarkType.leftShoulder,
          PoseLandmarkType.leftHip,
          PoseLandmarkType.rightHip,
          PoseLandmarkType.leftElbow,
          PoseLandmarkType.leftWrist,
          PoseLandmarkType.leftKnee,
          PoseLandmarkType.leftAnkle,
        });
      },
    );

    test(
      'hold requirements mirror mixed-side configured geometry for the opposite target side',
      () {
        final requirementSet = requirements.resolve(
          config: _alternateHoldConfig(),
          engineKind: EngineKind.hold,
          holdContract: HoldContracts.plankFamily,
          holdSide: HoldSide.right,
        );

        expect(
          requirementSet.requiredAngleTriplets.map(_tripletKey),
          unorderedEquals(<String>{
            'rightShoulder->rightHip->leftHip',
            'rightHip->rightElbow->rightWrist',
            'rightShoulder->rightKnee->rightAnkle',
          }),
        );
      },
    );
  });
}

ExerciseConfig _holdConfig() {
  return ExerciseConfig(
    name: 'Plank',
    primaryJoint: PoseLandmarkType.leftHip,
    joint1: PoseLandmarkType.leftShoulder,
    joint2: PoseLandmarkType.leftAnkle,
    thresholdNeutral: 160.0,
    thresholdActive: 168.0,
    thresholdPeak: 0.0,
    holdPosture: const HoldPostureConfig(
      activePostureAngle: 160.0,
      bodyLineEntryAngle: 168.0,
      bodyLineSustainAngle: 166.0,
      armSupportMinAngle: 60.0,
      armSupportMaxAngle: 120.0,
      legExtensionMinAngle: 165.0,
      breakGraceDuration: Duration(milliseconds: 300),
    ),
    holdSignals: const HoldSignalExtractionConfig(
      referenceSide: HoldSide.left,
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
    thresholdNeutral: 160.0,
    thresholdActive: 168.0,
    thresholdPeak: 0.0,
    holdPosture: const HoldPostureConfig(
      activePostureAngle: 160.0,
      bodyLineEntryAngle: 168.0,
      bodyLineSustainAngle: 166.0,
      armSupportMinAngle: 60.0,
      armSupportMaxAngle: 120.0,
      legExtensionMinAngle: 165.0,
      breakGraceDuration: Duration(milliseconds: 300),
    ),
    holdSignals: const HoldSignalExtractionConfig(
      referenceSide: HoldSide.left,
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

String _tripletKey(PoseAngleTriplet triplet) {
  return '${triplet.first.name}->${triplet.middle.name}->${triplet.last.name}';
}

String _segmentKey(PoseLandmarkSegment segment) {
  return '${segment.first.name}->${segment.second.name}';
}
