import 'camera_view_contract.dart';

/// User-setup camera-view outcome for one preparation frame.
enum SetupCameraViewAdvisoryStatus {
  insufficientEvidence,
  indeterminate,
  preferred,
  supported,
  unsupported,
}

/// A pose point normalized against the longest camera-image side.
///
/// Using one shared scale for x, y, and z preserves body proportions across
/// portrait and landscape images. Coordinates are not clamped because only
/// pair distances are consumed by the orientation evaluator.
class SetupCameraViewPoint {
  SetupCameraViewPoint({
    required this.x,
    required this.y,
    required this.z,
    required this.likelihood,
  }) {
    if (!x.isFinite || !y.isFinite || !z.isFinite || !likelihood.isFinite) {
      throw ArgumentError('Setup camera-view points must be finite.');
    }
    if (likelihood < 0 || likelihood > 1) {
      throw ArgumentError.value(
        likelihood,
        'likelihood',
        'Landmark likelihood must be between zero and one.',
      );
    }
  }

  final double x;
  final double y;
  final double z;
  final double likelihood;

  bool isConfident(double minimumLikelihood) {
    return likelihood >= minimumLikelihood;
  }
}

/// Bilateral torso landmarks used to infer a front or side body view.
class SetupCameraViewPose {
  const SetupCameraViewPose({
    this.leftShoulder,
    this.rightShoulder,
    this.leftHip,
    this.rightHip,
  });

  final SetupCameraViewPoint? leftShoulder;
  final SetupCameraViewPoint? rightShoulder;
  final SetupCameraViewPoint? leftHip;
  final SetupCameraViewPoint? rightHip;
}

/// Conservative, non-clinical orientation heuristics.
class SetupCameraViewThresholds {
  const SetupCameraViewThresholds({
    required this.minimumLandmarkLikelihood,
    required this.minimumTorsoLengthRatio,
    required this.sidePairWidthRatio,
    required this.frontPairWidthRatio,
    required this.frontDepthSeparationRatio,
    required this.sideDepthSeparationRatio,
    required this.depthEvidenceWeight,
    required this.singlePairEvidenceFactor,
    required this.minimumClassificationConfidence,
    required this.minimumScoreSeparation,
  }) : assert(minimumLandmarkLikelihood >= 0),
       assert(minimumLandmarkLikelihood <= 1),
       assert(minimumTorsoLengthRatio > 0),
       assert(sidePairWidthRatio >= 0),
       assert(frontPairWidthRatio > sidePairWidthRatio),
       assert(frontDepthSeparationRatio >= 0),
       assert(sideDepthSeparationRatio > frontDepthSeparationRatio),
       assert(depthEvidenceWeight >= 0),
       assert(depthEvidenceWeight <= 1),
       assert(singlePairEvidenceFactor > 0),
       assert(singlePairEvidenceFactor <= 1),
       assert(minimumClassificationConfidence >= 0),
       assert(minimumClassificationConfidence <= 1),
       assert(minimumScoreSeparation >= 0),
       assert(minimumScoreSeparation <= 1);

  static const SetupCameraViewThresholds defaults = SetupCameraViewThresholds(
    minimumLandmarkLikelihood: 0.5,
    minimumTorsoLengthRatio: 0.08,
    sidePairWidthRatio: 0.28,
    frontPairWidthRatio: 0.52,
    frontDepthSeparationRatio: 0.12,
    sideDepthSeparationRatio: 0.34,
    depthEvidenceWeight: 0.15,
    singlePairEvidenceFactor: 0.78,
    minimumClassificationConfidence: 0.6,
    minimumScoreSeparation: 0.18,
  );

  final double minimumLandmarkLikelihood;
  final double minimumTorsoLengthRatio;
  final double sidePairWidthRatio;
  final double frontPairWidthRatio;
  final double frontDepthSeparationRatio;
  final double sideDepthSeparationRatio;
  final double depthEvidenceWeight;
  final double singlePairEvidenceFactor;
  final double minimumClassificationConfidence;
  final double minimumScoreSeparation;
}

/// Camera-view evidence and its relationship with the exercise contract.
class SetupCameraViewAssessment {
  const SetupCameraViewAssessment({
    required this.status,
    required this.detectedView,
    required this.recommendedView,
    required this.detectedViewSupport,
    required this.confidence,
    required this.frontScore,
    required this.sideScore,
    required this.completeBilateralPairCount,
    required this.evidenceLikelihood,
    required this.torsoLengthRatio,
    required this.averagePairWidthRatio,
    required this.averageDepthSeparationRatio,
  });

  final SetupCameraViewAdvisoryStatus status;
  final CameraView? detectedView;
  final CameraView? recommendedView;
  final CameraViewSupport? detectedViewSupport;
  final double confidence;
  final double frontScore;
  final double sideScore;
  final int completeBilateralPairCount;
  final double evidenceLikelihood;
  final double? torsoLengthRatio;
  final double? averagePairWidthRatio;
  final double? averageDepthSeparationRatio;

  bool get hasConclusiveView => detectedView != null;

  bool get matchesPreferredView =>
      status == SetupCameraViewAdvisoryStatus.preferred;
}
