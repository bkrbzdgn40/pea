import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_metrics.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/pose_landmark_mirror.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_side.dart';

void main() {
  group('mirrorPoseLandmarkType', () {
    for (final pair
        in <({String name, PoseLandmarkType left, PoseLandmarkType right})>[
          (
            name: 'eye inner',
            left: PoseLandmarkType.leftEyeInner,
            right: PoseLandmarkType.rightEyeInner,
          ),
          (
            name: 'eye',
            left: PoseLandmarkType.leftEye,
            right: PoseLandmarkType.rightEye,
          ),
          (
            name: 'eye outer',
            left: PoseLandmarkType.leftEyeOuter,
            right: PoseLandmarkType.rightEyeOuter,
          ),
          (
            name: 'ear',
            left: PoseLandmarkType.leftEar,
            right: PoseLandmarkType.rightEar,
          ),
          (
            name: 'mouth',
            left: PoseLandmarkType.leftMouth,
            right: PoseLandmarkType.rightMouth,
          ),
          (
            name: 'shoulder',
            left: PoseLandmarkType.leftShoulder,
            right: PoseLandmarkType.rightShoulder,
          ),
          (
            name: 'elbow',
            left: PoseLandmarkType.leftElbow,
            right: PoseLandmarkType.rightElbow,
          ),
          (
            name: 'wrist',
            left: PoseLandmarkType.leftWrist,
            right: PoseLandmarkType.rightWrist,
          ),
          (
            name: 'pinky',
            left: PoseLandmarkType.leftPinky,
            right: PoseLandmarkType.rightPinky,
          ),
          (
            name: 'index',
            left: PoseLandmarkType.leftIndex,
            right: PoseLandmarkType.rightIndex,
          ),
          (
            name: 'thumb',
            left: PoseLandmarkType.leftThumb,
            right: PoseLandmarkType.rightThumb,
          ),
          (
            name: 'hip',
            left: PoseLandmarkType.leftHip,
            right: PoseLandmarkType.rightHip,
          ),
          (
            name: 'knee',
            left: PoseLandmarkType.leftKnee,
            right: PoseLandmarkType.rightKnee,
          ),
          (
            name: 'ankle',
            left: PoseLandmarkType.leftAnkle,
            right: PoseLandmarkType.rightAnkle,
          ),
          (
            name: 'heel',
            left: PoseLandmarkType.leftHeel,
            right: PoseLandmarkType.rightHeel,
          ),
          (
            name: 'foot index',
            left: PoseLandmarkType.leftFootIndex,
            right: PoseLandmarkType.rightFootIndex,
          ),
        ]) {
      test('swaps the paired ${pair.name} landmarks in both directions', () {
        expect(mirrorPoseLandmarkType(pair.left), pair.right);
        expect(mirrorPoseLandmarkType(pair.right), pair.left);
      });
    }

    test('keeps center landmarks unchanged', () {
      expect(
        mirrorPoseLandmarkType(PoseLandmarkType.nose),
        PoseLandmarkType.nose,
      );
    });
  });

  group('resolveHoldLandmarkForSide', () {
    test('applies the configured reference-side mirroring matrix', () {
      expect(
        resolveHoldLandmarkForSide(
          configuredLandmark: PoseLandmarkType.leftShoulder,
          referenceSide: HoldSide.left,
          targetSide: HoldSide.left,
        ),
        PoseLandmarkType.leftShoulder,
      );
      expect(
        resolveHoldLandmarkForSide(
          configuredLandmark: PoseLandmarkType.leftShoulder,
          referenceSide: HoldSide.left,
          targetSide: HoldSide.right,
        ),
        PoseLandmarkType.rightShoulder,
      );
      expect(
        resolveHoldLandmarkForSide(
          configuredLandmark: PoseLandmarkType.rightHip,
          referenceSide: HoldSide.left,
          targetSide: HoldSide.right,
        ),
        PoseLandmarkType.leftHip,
      );
      expect(
        resolveHoldLandmarkForSide(
          configuredLandmark: PoseLandmarkType.nose,
          referenceSide: HoldSide.left,
          targetSide: HoldSide.right,
        ),
        PoseLandmarkType.nose,
      );
      expect(
        resolveHoldLandmarkForSide(
          configuredLandmark: PoseLandmarkType.rightFootIndex,
          referenceSide: HoldSide.right,
          targetSide: HoldSide.left,
        ),
        PoseLandmarkType.leftFootIndex,
      );
    });
  });

  group('resolveRangeRepLandmarkForSide', () {
    test('keeps left landmarks and mirrors right landmarks', () {
      expect(
        resolveRangeRepLandmarkForSide(
          PoseLandmarkType.leftKnee,
          RangeRepSide.left,
        ),
        PoseLandmarkType.leftKnee,
      );
      expect(
        resolveRangeRepLandmarkForSide(
          PoseLandmarkType.leftKnee,
          RangeRepSide.right,
        ),
        PoseLandmarkType.rightKnee,
      );
    });
  });
}
