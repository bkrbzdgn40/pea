import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../domain/models/assessment_models.dart';
import 'exercise_landmark_requirements.dart';
import 'pose_quality_policy.dart';

/// Assessment-specific landmark contracts backed by the shared runtime
/// pose-quality policy.
///
/// Confidence and geometry thresholds remain identical to workout analysis.
/// These are input-quality heuristics, not clinical confidence cutoffs.
class AssessmentPoseQualityPolicy {
  const AssessmentPoseQualityPolicy({
    PoseQualityPolicy poseQualityPolicy = const PoseQualityPolicy(),
  }) : _poseQualityPolicy = poseQualityPolicy;

  final PoseQualityPolicy _poseQualityPolicy;

  static const ExerciseLandmarkRequirementSet _squatRequirements =
      ExerciseLandmarkRequirementSet(
        requiredLandmarks: <PoseLandmarkType>{
          PoseLandmarkType.leftShoulder,
          PoseLandmarkType.rightShoulder,
          PoseLandmarkType.leftHip,
          PoseLandmarkType.rightHip,
          PoseLandmarkType.leftKnee,
          PoseLandmarkType.rightKnee,
          PoseLandmarkType.leftAnkle,
          PoseLandmarkType.rightAnkle,
        },
        requiredAngleTriplets: <PoseAngleTriplet>[
          PoseAngleTriplet(
            first: PoseLandmarkType.leftHip,
            middle: PoseLandmarkType.leftKnee,
            last: PoseLandmarkType.leftAnkle,
          ),
          PoseAngleTriplet(
            first: PoseLandmarkType.rightHip,
            middle: PoseLandmarkType.rightKnee,
            last: PoseLandmarkType.rightAnkle,
          ),
        ],
        requiredSegments: <PoseLandmarkSegment>[
          PoseLandmarkSegment(
            first: PoseLandmarkType.leftShoulder,
            second: PoseLandmarkType.leftHip,
          ),
          PoseLandmarkSegment(
            first: PoseLandmarkType.rightShoulder,
            second: PoseLandmarkType.rightHip,
          ),
        ],
      );

  static const ExerciseLandmarkRequirementSet _balanceRequirements =
      ExerciseLandmarkRequirementSet(
        requiredLandmarks: <PoseLandmarkType>{
          PoseLandmarkType.leftShoulder,
          PoseLandmarkType.rightShoulder,
          PoseLandmarkType.leftHip,
          PoseLandmarkType.rightHip,
          PoseLandmarkType.leftAnkle,
          PoseLandmarkType.rightAnkle,
        },
        requiredAngleTriplets: <PoseAngleTriplet>[],
        requiredSegments: <PoseLandmarkSegment>[
          PoseLandmarkSegment(
            first: PoseLandmarkType.leftShoulder,
            second: PoseLandmarkType.leftHip,
          ),
          PoseLandmarkSegment(
            first: PoseLandmarkType.rightShoulder,
            second: PoseLandmarkType.rightHip,
          ),
        ],
      );

  static const ExerciseLandmarkRequirementSet _shoulderMobilityRequirements =
      ExerciseLandmarkRequirementSet(
        requiredLandmarks: <PoseLandmarkType>{
          PoseLandmarkType.leftHip,
          PoseLandmarkType.rightHip,
          PoseLandmarkType.leftShoulder,
          PoseLandmarkType.rightShoulder,
          PoseLandmarkType.leftElbow,
          PoseLandmarkType.rightElbow,
        },
        requiredAngleTriplets: <PoseAngleTriplet>[
          PoseAngleTriplet(
            first: PoseLandmarkType.leftHip,
            middle: PoseLandmarkType.leftShoulder,
            last: PoseLandmarkType.leftElbow,
          ),
          PoseAngleTriplet(
            first: PoseLandmarkType.rightHip,
            middle: PoseLandmarkType.rightShoulder,
            last: PoseLandmarkType.rightElbow,
          ),
        ],
        requiredSegments: <PoseLandmarkSegment>[],
      );

  PoseQualityAssessment assess({
    required Pose pose,
    required AssessmentType type,
  }) {
    final requirements = switch (type) {
      AssessmentType.squat => _squatRequirements,
      AssessmentType.balance => _balanceRequirements,
      AssessmentType.shoulderMobility => _shoulderMobilityRequirements,
    };
    return _poseQualityPolicy.assessRequirementSet(
      pose: pose,
      requirementSet: requirements,
    );
  }
}
