import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

/// Minimal measurement contract between pose extraction and the current engine.
class ExerciseMetrics {
  const ExerciseMetrics({
    required this.primaryAngle,
    required this.formMetric,
    this.bodyLineAngle,
    this.armSupportAngle,
    this.legExtensionAngle,
    required this.hasPose,
    required this.landmarks,
  });

  const ExerciseMetrics.noPose()
    : primaryAngle = 0,
      formMetric = 0,
      bodyLineAngle = null,
      armSupportAngle = null,
      legExtensionAngle = null,
      hasPose = false,
      landmarks = const [];

  final double primaryAngle;
  final double formMetric;
  final double? bodyLineAngle;
  final double? armSupportAngle;
  final double? legExtensionAngle;
  final bool hasPose;
  final List<PoseLandmark> landmarks;
}
