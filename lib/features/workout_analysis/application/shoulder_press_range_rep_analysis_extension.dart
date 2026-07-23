import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import 'exercise_metrics.dart';
import 'range_rep_exercise_analysis_extension.dart';
import 'range_rep_extension_pose_utils.dart';
import 'range_rep_noop_analysis_extension.dart';

/// Shoulder Press uses elbow extension as its primary lifecycle metric.
///
/// A straight arm beside the torso can produce the same high elbow angle as an
/// overhead lockout. For bilateral presses, that ambiguity can otherwise let a
/// single overhead arm pair with the opposite straight-down arm and satisfy the
/// generic PEAK threshold.
///
/// Keep the generic elbow-angle lifecycle, but require both wrists to be above
/// their corresponding shoulders before PEAK may be confirmed.
class ShoulderPressRangeRepExerciseAnalysisExtension
    extends NoOpRangeRepExerciseAnalysisExtension
    implements RangeRepPeakEntryGate {
  @override
  bool allowsPeakEntry(ExerciseMetrics metrics) {
    final pose = poseFromLandmarks(metrics.landmarks);
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final leftWrist = pose.landmarks[PoseLandmarkType.leftWrist];
    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
    final rightWrist = pose.landmarks[PoseLandmarkType.rightWrist];

    if (leftShoulder == null ||
        leftWrist == null ||
        rightShoulder == null ||
        rightWrist == null) {
      return false;
    }

    return leftWrist.y < leftShoulder.y && rightWrist.y < rightShoulder.y;
  }
}
