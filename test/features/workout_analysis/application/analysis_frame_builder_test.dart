import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:pose_estimation_app/core/utils/moving_average.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/analysis_frame_builder.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_metrics.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_contract.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_signal_values.dart';

void main() {
  group('WorkoutAnalysisFrameBuilder', () {
    test('smooths each hold signal independently', () {
      final builder = const WorkoutAnalysisFrameBuilder();
      final primaryMetricFilter = MovingAverageFilter(windowSize: 2);
      final formMetricFilter = MovingAverageFilter(windowSize: 2);
      final holdSignalFilters = <HoldSignal, MovingAverageFilter>{
        for (final signal in HoldSignal.values)
          signal: MovingAverageFilter(windowSize: 2),
      };

      builder.build(
        metrics: _holdMetrics(
          bodyLineAngle: 170.0,
          armSupportAngle: 90.0,
          legExtensionAngle: 170.0,
        ),
        primaryMetricFilter: primaryMetricFilter,
        formMetricFilter: formMetricFilter,
        holdSignalFilters: holdSignalFilters,
      );

      final secondFrame = builder.build(
        metrics: _holdMetrics(
          bodyLineAngle: 150.0,
          armSupportAngle: 50.0,
          legExtensionAngle: 170.0,
        ),
        primaryMetricFilter: primaryMetricFilter,
        formMetricFilter: formMetricFilter,
        holdSignalFilters: holdSignalFilters,
      );

      expect(secondFrame.bodyLineAngle, closeTo(160.0, 0.001));
      expect(secondFrame.armSupportAngle, closeTo(70.0, 0.001));
      expect(secondFrame.legExtensionAngle, closeTo(170.0, 0.001));
    });
  });
}

ExerciseMetrics _holdMetrics({
  required double bodyLineAngle,
  required double armSupportAngle,
  required double legExtensionAngle,
}) {
  return ExerciseMetrics(
    primaryAngle: bodyLineAngle,
    formMetric: bodyLineAngle,
    hasPrimaryAngle: true,
    hasFormMetric: true,
    hasPose: true,
    landmarks: const <PoseLandmark>[],
    leftRangeRepMetrics: const RangeRepSideMetrics.unavailable(
      RangeRepSide.left,
    ),
    rightRangeRepMetrics: const RangeRepSideMetrics.unavailable(
      RangeRepSide.right,
    ),
    holdSignalValues: HoldSignalValues(
      values: <HoldSignal, double>{
        HoldSignal.alignment: bodyLineAngle,
        HoldSignal.support: armSupportAngle,
        HoldSignal.extension: legExtensionAngle,
      },
    ),
  );
}
