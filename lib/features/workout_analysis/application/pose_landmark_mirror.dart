import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../domain/models/hold_side.dart';
import 'exercise_metrics.dart';

PoseLandmarkType resolveRangeRepLandmarkForSide(
  PoseLandmarkType configuredLandmark,
  RangeRepSide side,
) {
  if (side == RangeRepSide.left) {
    return configuredLandmark;
  }

  return mirrorPoseLandmarkType(configuredLandmark);
}

PoseLandmarkType resolveHoldLandmarkForSide({
  required PoseLandmarkType configuredLandmark,
  required HoldSide referenceSide,
  required HoldSide targetSide,
}) {
  if (referenceSide == targetSide) {
    return configuredLandmark;
  }

  return mirrorPoseLandmarkType(configuredLandmark);
}

PoseLandmarkType mirrorPoseLandmarkType(PoseLandmarkType landmarkType) {
  switch (landmarkType) {
    case PoseLandmarkType.leftEyeInner:
      return PoseLandmarkType.rightEyeInner;
    case PoseLandmarkType.leftEye:
      return PoseLandmarkType.rightEye;
    case PoseLandmarkType.leftEyeOuter:
      return PoseLandmarkType.rightEyeOuter;
    case PoseLandmarkType.rightEyeInner:
      return PoseLandmarkType.leftEyeInner;
    case PoseLandmarkType.rightEye:
      return PoseLandmarkType.leftEye;
    case PoseLandmarkType.rightEyeOuter:
      return PoseLandmarkType.leftEyeOuter;
    case PoseLandmarkType.leftEar:
      return PoseLandmarkType.rightEar;
    case PoseLandmarkType.rightEar:
      return PoseLandmarkType.leftEar;
    case PoseLandmarkType.leftMouth:
      return PoseLandmarkType.rightMouth;
    case PoseLandmarkType.rightMouth:
      return PoseLandmarkType.leftMouth;
    case PoseLandmarkType.leftShoulder:
      return PoseLandmarkType.rightShoulder;
    case PoseLandmarkType.rightShoulder:
      return PoseLandmarkType.leftShoulder;
    case PoseLandmarkType.leftElbow:
      return PoseLandmarkType.rightElbow;
    case PoseLandmarkType.rightElbow:
      return PoseLandmarkType.leftElbow;
    case PoseLandmarkType.leftWrist:
      return PoseLandmarkType.rightWrist;
    case PoseLandmarkType.rightWrist:
      return PoseLandmarkType.leftWrist;
    case PoseLandmarkType.leftPinky:
      return PoseLandmarkType.rightPinky;
    case PoseLandmarkType.rightPinky:
      return PoseLandmarkType.leftPinky;
    case PoseLandmarkType.leftIndex:
      return PoseLandmarkType.rightIndex;
    case PoseLandmarkType.rightIndex:
      return PoseLandmarkType.leftIndex;
    case PoseLandmarkType.leftThumb:
      return PoseLandmarkType.rightThumb;
    case PoseLandmarkType.rightThumb:
      return PoseLandmarkType.leftThumb;
    case PoseLandmarkType.leftHip:
      return PoseLandmarkType.rightHip;
    case PoseLandmarkType.rightHip:
      return PoseLandmarkType.leftHip;
    case PoseLandmarkType.leftKnee:
      return PoseLandmarkType.rightKnee;
    case PoseLandmarkType.rightKnee:
      return PoseLandmarkType.leftKnee;
    case PoseLandmarkType.leftAnkle:
      return PoseLandmarkType.rightAnkle;
    case PoseLandmarkType.rightAnkle:
      return PoseLandmarkType.leftAnkle;
    case PoseLandmarkType.leftHeel:
      return PoseLandmarkType.rightHeel;
    case PoseLandmarkType.rightHeel:
      return PoseLandmarkType.leftHeel;
    case PoseLandmarkType.leftFootIndex:
      return PoseLandmarkType.rightFootIndex;
    case PoseLandmarkType.rightFootIndex:
      return PoseLandmarkType.leftFootIndex;
    default:
      return landmarkType;
  }
}
