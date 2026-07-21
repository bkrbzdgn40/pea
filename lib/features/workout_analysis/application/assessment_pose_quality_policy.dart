import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../domain/models/assessment_models.dart';
import 'exercise_landmark_requirements.dart';
import 'exercise_metrics.dart';
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

  static const ExerciseLandmarkRequirementSet _squatLeftRequirements =
      ExerciseLandmarkRequirementSet(
        requiredLandmarks: <PoseLandmarkType>{
          PoseLandmarkType.leftShoulder,
          PoseLandmarkType.leftHip,
          PoseLandmarkType.leftKnee,
          PoseLandmarkType.leftAnkle,
        },
        requiredAngleTriplets: <PoseAngleTriplet>[
          PoseAngleTriplet(
            first: PoseLandmarkType.leftHip,
            middle: PoseLandmarkType.leftKnee,
            last: PoseLandmarkType.leftAnkle,
          ),
        ],
        requiredSegments: <PoseLandmarkSegment>[
          PoseLandmarkSegment(
            first: PoseLandmarkType.leftShoulder,
            second: PoseLandmarkType.leftHip,
          ),
        ],
      );

  static const ExerciseLandmarkRequirementSet _squatRightRequirements =
      ExerciseLandmarkRequirementSet(
        requiredLandmarks: <PoseLandmarkType>{
          PoseLandmarkType.rightShoulder,
          PoseLandmarkType.rightHip,
          PoseLandmarkType.rightKnee,
          PoseLandmarkType.rightAnkle,
        },
        requiredAngleTriplets: <PoseAngleTriplet>[
          PoseAngleTriplet(
            first: PoseLandmarkType.rightHip,
            middle: PoseLandmarkType.rightKnee,
            last: PoseLandmarkType.rightAnkle,
          ),
        ],
        requiredSegments: <PoseLandmarkSegment>[
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
    if (type == AssessmentType.squat) {
      return _assessSideProfileSquat(pose);
    }

    final requirements = switch (type) {
      AssessmentType.squat => throw StateError('Handled above.'),
      AssessmentType.balance => _balanceRequirements,
      AssessmentType.shoulderMobility => _shoulderMobilityRequirements,
    };
    return _poseQualityPolicy.assessRequirementSet(
      pose: pose,
      requirementSet: requirements,
    );
  }

  PoseQualityAssessment _assessSideProfileSquat(Pose pose) {
    final left = _poseQualityPolicy.assessRequirementSet(
      pose: pose,
      requirementSet: _squatLeftRequirements,
      side: RangeRepSide.left,
    );
    final right = _poseQualityPolicy.assessRequirementSet(
      pose: pose,
      requirementSet: _squatRightRequirements,
      side: RangeRepSide.right,
    );

    if (left.isAccepted != right.isAccepted) {
      return left.isAccepted ? left : right;
    }
    if (left.qualityScore != right.qualityScore) {
      return left.qualityScore > right.qualityScore ? left : right;
    }
    final leftMean = left.meanRequiredLikelihood ?? 0.0;
    final rightMean = right.meanRequiredLikelihood ?? 0.0;
    if (leftMean != rightMean) {
      return leftMean > rightMean ? left : right;
    }
    return left;
  }
}
