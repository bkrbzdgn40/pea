import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_metrics.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/analysis_frame.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_contract.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_signal_values.dart';

void main() {
  group('HoldSignalValues', () {
    test('copies source values and exposes an immutable view', () {
      final source = <HoldSignal, double>{HoldSignal.alignment: 170.0};
      final values = HoldSignalValues(values: source);

      source[HoldSignal.alignment] = 140.0;

      expect(values.valueFor(HoldSignal.alignment), 170.0);
      expect(
        () => values.asMap()[HoldSignal.support] = 90.0,
        throwsUnsupportedError,
      );
    });

    test('reports missing signals as unavailable', () {
      final values = HoldSignalValues(
        values: <HoldSignal, double>{HoldSignal.alignment: 170.0},
      );

      expect(values.hasValue(HoldSignal.alignment), isTrue);
      expect(values.valueFor(HoldSignal.alignment), 170.0);
      expect(values.hasValue(HoldSignal.support), isFalse);
      expect(values.valueFor(HoldSignal.support), isNull);
    });
  });

  group('hold compatibility transport', () {
    test(
      'ExerciseMetrics compatibility getters derive from holdSignalValues',
      () {
        final metrics = ExerciseMetrics(
          primaryAngle: 170.0,
          formMetric: 170.0,
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
              HoldSignal.alignment: 170.0,
              HoldSignal.support: 90.0,
              HoldSignal.extension: 168.0,
            },
          ),
        );

        expect(metrics.bodyLineAngle, 170.0);
        expect(metrics.armSupportAngle, 90.0);
        expect(metrics.legExtensionAngle, 168.0);
      },
    );

    test(
      'ExerciseMetrics noPose and copyWith preserve canonical hold signals',
      () {
        final noPose = const ExerciseMetrics.noPose();
        final metrics = ExerciseMetrics(
          primaryAngle: 170.0,
          formMetric: 170.0,
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
              HoldSignal.alignment: 170.0,
              HoldSignal.support: 90.0,
            },
          ),
        );
        final copied = metrics.copyWith();

        expect(noPose.holdSignalValues.signals, isEmpty);
        expect(copied.bodyLineAngle, 170.0);
        expect(copied.armSupportAngle, 90.0);
        expect(copied.legExtensionAngle, isNull);
      },
    );

    test(
      'AnalysisFrame compatibility getters derive from holdSignalValues',
      () {
        final frame = AnalysisFrame(
          primaryMetric: 170.0,
          formMetric: 170.0,
          holdSignalValues: HoldSignalValues(
            values: <HoldSignal, double>{
              HoldSignal.alignment: 170.0,
              HoldSignal.support: 90.0,
              HoldSignal.extension: 165.0,
            },
          ),
        );

        expect(frame.bodyLineAngle, 170.0);
        expect(frame.armSupportAngle, 90.0);
        expect(frame.legExtensionAngle, 165.0);
      },
    );
  });
}
