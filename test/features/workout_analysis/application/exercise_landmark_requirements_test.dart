import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/engine_kind.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_landmark_requirements.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_metrics.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_config.dart';

void main() {
  const requirements = ExerciseLandmarkRequirements();

  group('ExerciseLandmarkRequirements hold resolution', () {
    test('hold resolves the exact required landmark set', () {
      final requirementSet = requirements.resolve(
        config: _holdConfig(),
        engineKind: EngineKind.hold,
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

    test(
      'current hold requirements remain left-only when a right side is supplied',
      () {
        final requirementSet = requirements.resolve(
          config: _holdConfig(),
          engineKind: EngineKind.hold,
          side: RangeRepSide.right,
        );

        expect(requirementSet.requiredLandmarks, <PoseLandmarkType>{
          PoseLandmarkType.leftShoulder,
          PoseLandmarkType.leftElbow,
          PoseLandmarkType.leftWrist,
          PoseLandmarkType.leftHip,
          PoseLandmarkType.leftKnee,
          PoseLandmarkType.leftAnkle,
        });
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
  );
}

String _tripletKey(PoseAngleTriplet triplet) {
  return '${triplet.first.name}->${triplet.middle.name}->${triplet.last.name}';
}

String _segmentKey(PoseLandmarkSegment segment) {
  return '${segment.first.name}->${segment.second.name}';
}
