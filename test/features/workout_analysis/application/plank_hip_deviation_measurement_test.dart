import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:pose_estimation_app/core/utils/moving_average.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/analysis_frame_builder.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_metrics.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/plank_hip_deviation_measurement.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_contract.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_side.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_signal_values.dart';

import '../../../support/workout_analysis_test_support.dart';

void main() {
  const measurement = PlankHipDeviationMeasurement();

  group('PlankHipDeviationMeasurement', () {
    test('returns zero when hip lies on the shoulder-ankle line', () {
      final value = measurement.measureLandmarks(
        _landmarks(
          side: HoldSide.left,
          shoulderX: -1,
          shoulderY: 0,
          hipX: 0,
          hipY: 0,
          ankleX: 1,
          ankleY: 0,
        ),
        side: HoldSide.left,
      );

      expect(value, closeTo(0.0, 0.001));
    });

    test('normalizes hip deviation by shoulder-ankle length', () {
      final value = measurement.measureLandmarks(
        _landmarks(
          side: HoldSide.left,
          shoulderX: -1,
          shoulderY: 0,
          hipX: 0,
          hipY: 0.5,
          ankleX: 1,
          ankleY: 0,
        ),
        side: HoldSide.left,
      );

      expect(value, closeTo(0.25, 0.001));
    });

    test('mirrors the measurement to the selected right side', () {
      final landmarks = _landmarks(
        side: HoldSide.right,
        shoulderX: 3,
        shoulderY: 0,
        hipX: 4,
        hipY: 1,
        ankleX: 5,
        ankleY: 0,
      );

      expect(
        measurement.measureLandmarks(landmarks, side: HoldSide.right),
        closeTo(0.5, 0.001),
      );
      expect(
        measurement.measureLandmarks(landmarks, side: HoldSide.left),
        isNull,
      );
    });

    test('uniform scaling preserves the normalized signal', () {
      final original = measurement.measureLandmarks(
        _landmarks(
          side: HoldSide.left,
          shoulderX: -1,
          shoulderY: 0,
          hipX: 0,
          hipY: 1,
          ankleX: 1,
          ankleY: 0,
        ),
        side: HoldSide.left,
      );
      final scaled = measurement.measureLandmarks(
        _landmarks(
          side: HoldSide.left,
          shoulderX: -4,
          shoulderY: 0,
          hipX: 0,
          hipY: 4,
          ankleX: 4,
          ankleY: 0,
        ),
        side: HoldSide.left,
      );

      expect(scaled, closeTo(original!, 0.001));
    });

    test('returns null for missing landmarks and a degenerate body line', () {
      final missingAnkle = <PoseLandmark>[
        buildLandmark(PoseLandmarkType.leftShoulder, -1, 0, likelihood: 0.95),
        buildLandmark(PoseLandmarkType.leftHip, 0, 1, likelihood: 0.95),
      ];
      final zeroLength = _landmarks(
        side: HoldSide.left,
        shoulderX: 0,
        shoulderY: 0,
        hipX: 0,
        hipY: 1,
        ankleX: 0,
        ankleY: 0,
      );

      expect(
        measurement.measureLandmarks(missingAnkle, side: HoldSide.left),
        isNull,
      );
      expect(
        measurement.measureLandmarks(zeroLength, side: HoldSide.left),
        isNull,
      );
    });
  });

  test('analysis frame exposes hip deviation without replacing alignment', () {
    final metrics = ExerciseMetrics(
      primaryAngle: 180,
      formMetric: 90,
      hasPrimaryAngle: false,
      hasFormMetric: false,
      hasPose: true,
      landmarks: _landmarks(
        side: HoldSide.left,
        shoulderX: -1,
        shoulderY: 0,
        hipX: 0,
        hipY: 0.5,
        ankleX: 1,
        ankleY: 0,
      ),
      leftRangeRepMetrics: const RangeRepSideMetrics.unavailable(
        RangeRepSide.left,
      ),
      rightRangeRepMetrics: const RangeRepSideMetrics.unavailable(
        RangeRepSide.right,
      ),
      holdSignalValues: HoldSignalValues(
        values: const <HoldSignal, double>{
          HoldSignal.alignment: 160,
          HoldSignal.support: 90,
          HoldSignal.extension: 170,
        },
      ),
      holdSide: HoldSide.left,
    );

    final frame = const WorkoutAnalysisFrameBuilder().build(
      metrics: metrics,
      primaryMetricFilter: MovingAverageFilter(windowSize: 5),
      formMetricFilter: MovingAverageFilter(windowSize: 5),
      holdSignalFilters: <HoldSignal, MovingAverageFilter>{
        for (final signal in HoldSignal.values)
          signal: MovingAverageFilter(windowSize: 5),
      },
    );

    expect(frame.holdSignalValues.valueFor(HoldSignal.alignment), 160);
    expect(
      frame.holdSignalValues.valueFor(HoldSignal.hipDeviation),
      closeTo(0.25, 0.001),
    );
  });
}

List<PoseLandmark> _landmarks({
  required HoldSide side,
  required double shoulderX,
  required double shoulderY,
  required double hipX,
  required double hipY,
  required double ankleX,
  required double ankleY,
}) {
  final isLeft = side == HoldSide.left;
  final shoulderType = isLeft
      ? PoseLandmarkType.leftShoulder
      : PoseLandmarkType.rightShoulder;
  final hipType = isLeft ? PoseLandmarkType.leftHip : PoseLandmarkType.rightHip;
  final ankleType = isLeft
      ? PoseLandmarkType.leftAnkle
      : PoseLandmarkType.rightAnkle;

  return <PoseLandmark>[
    buildLandmark(shoulderType, shoulderX, shoulderY, likelihood: 0.95),
    buildLandmark(hipType, hipX, hipY, likelihood: 0.95),
    buildLandmark(ankleType, ankleX, ankleY, likelihood: 0.95),
  ];
}
