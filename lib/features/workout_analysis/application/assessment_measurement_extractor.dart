import 'dart:math' as math;

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../../../core/utils/angle_calculator.dart';
import '../../../core/utils/image_plane_geometry.dart';
import '../domain/models/assessment_models.dart';

/// Extracts camera-observable measurements for assessment mode.
///
/// These are 2D image-plane measurements and should not be presented as
/// clinical diagnoses or as a replacement for force-plate / 3D motion-capture
/// assessment. Missing landmarks stay null rather than becoming synthetic
/// zeroes.
class AssessmentMeasurementExtractor {
  const AssessmentMeasurementExtractor();

  SquatAssessmentObservation extractSquat(Pose pose, {AssessmentSide? side}) {
    final useLeft = side == null || side == AssessmentSide.left;
    final useRight = side == null || side == AssessmentSide.right;
    final leftKneeAngle = useLeft
        ? _jointAngle(
            pose,
            first: PoseLandmarkType.leftHip,
            middle: PoseLandmarkType.leftKnee,
            last: PoseLandmarkType.leftAnkle,
          )
        : null;
    final rightKneeAngle = useRight
        ? _jointAngle(
            pose,
            first: PoseLandmarkType.rightHip,
            middle: PoseLandmarkType.rightKnee,
            last: PoseLandmarkType.rightAnkle,
          )
        : null;
    final leftDepth = useLeft
        ? _hipDepthRatio(
            pose,
            hipType: PoseLandmarkType.leftHip,
            kneeType: PoseLandmarkType.leftKnee,
            ankleType: PoseLandmarkType.leftAnkle,
          )
        : null;
    final rightDepth = useRight
        ? _hipDepthRatio(
            pose,
            hipType: PoseLandmarkType.rightHip,
            kneeType: PoseLandmarkType.rightKnee,
            ankleType: PoseLandmarkType.rightAnkle,
          )
        : null;
    final torsoInclination = switch (side) {
      AssessmentSide.left => _sideTorsoInclination(
        pose,
        shoulderType: PoseLandmarkType.leftShoulder,
        hipType: PoseLandmarkType.leftHip,
      ),
      AssessmentSide.right => _sideTorsoInclination(
        pose,
        shoulderType: PoseLandmarkType.rightShoulder,
        hipType: PoseLandmarkType.rightHip,
      ),
      null => _torsoInclination(pose),
    };

    return SquatAssessmentObservation(
      leftKneeAngleDegrees: leftKneeAngle,
      rightKneeAngleDegrees: rightKneeAngle,
      hipDepthRatio: _averageAvailable(leftDepth, rightDepth),
      torsoInclinationDegrees: torsoInclination,
    );
  }

  BalanceAssessmentObservation extractBalance(
    Pose pose, {
    required AssessmentSide side,
    required DateTime capturedAt,
  }) {
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final rightHip = pose.landmarks[PoseLandmarkType.rightHip];
    final leftAnkle = pose.landmarks[PoseLandmarkType.leftAnkle];
    final rightAnkle = pose.landmarks[PoseLandmarkType.rightAnkle];

    if (leftShoulder == null ||
        rightShoulder == null ||
        leftHip == null ||
        rightHip == null ||
        leftAnkle == null ||
        rightAnkle == null) {
      return BalanceAssessmentObservation(
        side: side,
        capturedAt: capturedAt,
        shoulderCenterXNormalized: null,
        hipCenterXNormalized: null,
        raisedFootClearanceRatio: null,
      );
    }

    final shoulderCenter = _midpoint(leftShoulder, rightShoulder);
    final hipCenter = _midpoint(leftHip, rightHip);
    final torsoLength = _distance(shoulderCenter, hipCenter);
    if (torsoLength == 0.0) {
      return BalanceAssessmentObservation(
        side: side,
        capturedAt: capturedAt,
        shoulderCenterXNormalized: null,
        hipCenterXNormalized: null,
        raisedFootClearanceRatio: null,
      );
    }

    final stanceAnkle = side == AssessmentSide.left ? leftAnkle : rightAnkle;
    final raisedAnkle = side == AssessmentSide.left ? rightAnkle : leftAnkle;

    return BalanceAssessmentObservation(
      side: side,
      capturedAt: capturedAt,
      shoulderCenterXNormalized:
          (shoulderCenter.x - stanceAnkle.x) / torsoLength,
      hipCenterXNormalized: (hipCenter.x - stanceAnkle.x) / torsoLength,
      raisedFootClearanceRatio: (stanceAnkle.y - raisedAnkle.y) / torsoLength,
    );
  }

  ShoulderMobilityAssessmentObservation extractShoulderMobility(Pose pose) {
    final leftElevation = _jointAngle(
      pose,
      first: PoseLandmarkType.leftHip,
      middle: PoseLandmarkType.leftShoulder,
      last: PoseLandmarkType.leftElbow,
    );
    final rightElevation = _jointAngle(
      pose,
      first: PoseLandmarkType.rightHip,
      middle: PoseLandmarkType.rightShoulder,
      last: PoseLandmarkType.rightElbow,
    );

    return ShoulderMobilityAssessmentObservation(
      leftElevationDegrees: leftElevation,
      rightElevationDegrees: rightElevation,
      torsoInclinationDegrees: _torsoInclination(pose),
    );
  }

  double? _jointAngle(
    Pose pose, {
    required PoseLandmarkType first,
    required PoseLandmarkType middle,
    required PoseLandmarkType last,
  }) {
    final firstLandmark = pose.landmarks[first];
    final middleLandmark = pose.landmarks[middle];
    final lastLandmark = pose.landmarks[last];
    if (firstLandmark == null ||
        middleLandmark == null ||
        lastLandmark == null) {
      return null;
    }

    return AngleCalculator.calculate(
      _point(firstLandmark),
      _point(middleLandmark),
      _point(lastLandmark),
    );
  }

  double? _hipDepthRatio(
    Pose pose, {
    required PoseLandmarkType hipType,
    required PoseLandmarkType kneeType,
    required PoseLandmarkType ankleType,
  }) {
    final hip = pose.landmarks[hipType];
    final knee = pose.landmarks[kneeType];
    final ankle = pose.landmarks[ankleType];
    if (hip == null || knee == null || ankle == null) {
      return null;
    }

    final normalizationLength = _distance(_point(knee), _point(ankle));
    if (normalizationLength == 0.0) {
      return null;
    }

    return (knee.y - hip.y) / normalizationLength;
  }

  double? _sideTorsoInclination(
    Pose pose, {
    required PoseLandmarkType shoulderType,
    required PoseLandmarkType hipType,
  }) {
    final shoulder = pose.landmarks[shoulderType];
    final hip = pose.landmarks[hipType];
    if (shoulder == null || hip == null) {
      return null;
    }
    return imagePlaneInclination(_point(shoulder), _point(hip));
  }

  double? _torsoInclination(Pose pose) {
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final rightHip = pose.landmarks[PoseLandmarkType.rightHip];
    if (leftShoulder == null ||
        rightShoulder == null ||
        leftHip == null ||
        rightHip == null) {
      return null;
    }

    return imagePlaneInclination(
      _midpoint(leftShoulder, rightShoulder),
      _midpoint(leftHip, rightHip),
    );
  }

  math.Point<double> _midpoint(PoseLandmark first, PoseLandmark second) {
    return math.Point<double>(
      (first.x + second.x) / 2.0,
      (first.y + second.y) / 2.0,
    );
  }

  math.Point<double> _point(PoseLandmark landmark) {
    return math.Point<double>(landmark.x, landmark.y);
  }

  double _distance(math.Point<double> first, math.Point<double> second) {
    final dx = second.x - first.x;
    final dy = second.y - first.y;
    return math.sqrt((dx * dx) + (dy * dy));
  }

  double? _averageAvailable(double? left, double? right) {
    if (left != null && right != null) {
      return (left + right) / 2.0;
    }
    return left ?? right;
  }
}
