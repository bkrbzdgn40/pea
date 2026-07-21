import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/assessment_pose_quality_policy.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/pose_quality_policy.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/assessment_models.dart';

void main() {
  const policy = AssessmentPoseQualityPolicy();

  group('AssessmentPoseQualityPolicy', () {
    test('accepts a complete high-confidence squat pose', () {
      final assessment = policy.assess(
        pose: _squatPose(),
        type: AssessmentType.squat,
      );

      expect(assessment.isAccepted, isTrue);
      expect(assessment.rejectionReason, isNull);
      expect(assessment.requiredLandmarkCount, 8);
      expect(assessment.acceptedLandmarkCount, 8);
    });

    test('rejects an assessment pose with a missing required landmark', () {
      final landmarks = Map<PoseLandmarkType, PoseLandmark>.from(
        _squatPose().landmarks,
      )..remove(PoseLandmarkType.rightAnkle);

      final assessment = policy.assess(
        pose: Pose(landmarks: landmarks),
        type: AssessmentType.squat,
      );

      expect(assessment.isAccepted, isFalse);
      expect(
        assessment.rejectionReason,
        PoseRejectionReason.missingRequiredLandmark,
      );
    });

    test('rejects a low-confidence required landmark', () {
      final assessment = policy.assess(
        pose: _squatPose(
          likelihoodOverrides: const <PoseLandmarkType, double>{
            PoseLandmarkType.leftAnkle: 0.49,
          },
        ),
        type: AssessmentType.squat,
      );

      expect(assessment.isAccepted, isFalse);
      expect(
        assessment.rejectionReason,
        PoseRejectionReason.lowLandmarkLikelihood,
      );
    });

    test(
      'rejects low mean confidence even when every landmark clears minimum',
      () {
        final assessment = policy.assess(
          pose: _squatPose(defaultLikelihood: 0.60),
          type: AssessmentType.squat,
        );

        expect(assessment.isAccepted, isFalse);
        expect(
          assessment.rejectionReason,
          PoseRejectionReason.lowMeanLikelihood,
        );
      },
    );

    test('rejects degenerate shoulder mobility geometry', () {
      final pose = _pose(<PoseLandmarkType, (double, double)>{
        PoseLandmarkType.leftHip: (-1, 2),
        PoseLandmarkType.rightHip: (1, 2),
        PoseLandmarkType.leftShoulder: (-1, 0),
        PoseLandmarkType.rightShoulder: (1, 0),
        PoseLandmarkType.leftElbow: (-1, 0),
        PoseLandmarkType.rightElbow: (1, -2),
      });

      final assessment = policy.assess(
        pose: pose,
        type: AssessmentType.shoulderMobility,
      );

      expect(assessment.isAccepted, isFalse);
      expect(
        assessment.rejectionReason,
        PoseRejectionReason.degenerateGeometry,
      );
    });
  });
}

Pose _squatPose({
  double defaultLikelihood = 1.0,
  Map<PoseLandmarkType, double> likelihoodOverrides =
      const <PoseLandmarkType, double>{},
}) {
  return _pose(
    <PoseLandmarkType, (double, double)>{
      PoseLandmarkType.leftShoulder: (-1, 0),
      PoseLandmarkType.rightShoulder: (1, 0),
      PoseLandmarkType.leftHip: (-1, 2),
      PoseLandmarkType.rightHip: (1, 2),
      PoseLandmarkType.leftKnee: (-1, 4),
      PoseLandmarkType.rightKnee: (1, 4),
      PoseLandmarkType.leftAnkle: (-1, 6),
      PoseLandmarkType.rightAnkle: (1, 6),
    },
    defaultLikelihood: defaultLikelihood,
    likelihoodOverrides: likelihoodOverrides,
  );
}

Pose _pose(
  Map<PoseLandmarkType, (double, double)> coordinates, {
  double defaultLikelihood = 1.0,
  Map<PoseLandmarkType, double> likelihoodOverrides =
      const <PoseLandmarkType, double>{},
}) {
  return Pose(
    landmarks: <PoseLandmarkType, PoseLandmark>{
      for (final entry in coordinates.entries)
        entry.key: PoseLandmark(
          type: entry.key,
          x: entry.value.$1,
          y: entry.value.$2,
          z: 0,
          likelihood: likelihoodOverrides[entry.key] ?? defaultLikelihood,
        ),
    },
  );
}
