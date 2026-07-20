import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import 'exercise_metrics.dart';

RangeRepSide? rangeRepSideFromLabel(String? sideLabel) {
  return switch (sideLabel) {
    'left' => RangeRepSide.left,
    'right' => RangeRepSide.right,
    _ => null,
  };
}

Pose poseFromLandmarks(List<PoseLandmark> landmarks) {
  return Pose(
    landmarks: <PoseLandmarkType, PoseLandmark>{
      for (final landmark in landmarks) landmark.type: landmark,
    },
  );
}
