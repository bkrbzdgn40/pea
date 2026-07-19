import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_metrics.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/squat_hip_depth_measurement.dart';

import '../../../support/workout_analysis_test_support.dart';

void main() {
  const measurement = SquatHipDepthMeasurement();

  test('returns 1 when the selected