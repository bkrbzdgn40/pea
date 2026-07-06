import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

/// Minimal measurement contract between pose extraction and the current engine.
class ExerciseMetrics {
  const ExerciseMetrics({
    required this.primaryAngle,
    required this.formMetric,
    required this.hasPose,
    required this.landmarks,
  });

  const ExerciseMetrics.noPose()
    : primaryAngle = 0,
      formMetric = 0,
      hasPose = false,
      landmarks = const [];

  final double primaryAngle;
  final double formMetric;
  final bool hasPose;
  final List<PoseLandmark> landmarks;
}
