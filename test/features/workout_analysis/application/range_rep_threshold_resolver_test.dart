import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/range_rep_threshold_resolver.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/range_rep_contract.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/session_calibration_baseline.dart';

import '../../../support/workout_analysis_test_support.dart';

void main() {
  const resolver = RangeRepThresholdResolver();

  test(
    'sit-up calibration policy keeps the effective threshold at the 60 degree base threshold',
    () {
      final config = loadExerciseConfig('assets/config/exercises/sit_up.json');

      final resolution = resolver.resolve(
        analysisKind: 'rangeRep',
        config: config,
        baseThreshold: config.formThreshold,
        formThresholdCalibrationPolicy:
            RangeRepContracts.sitUp.formThresholdCalibrationPolicy,
        sessionCalibrationBaseline: const SessionCalibrationBaseline(
          analysisKind: 'rangeRep',
          sampleCount: 3,
          selectedSideLabel: 'left',
          formMetricBaseline: 120.0,
        ),
        selectedRangeRepSide: 'left',
      );

      expect(resolution.baseThreshold, 60.0);
      expect(resolution.effectiveThreshold, 60.0);
      expect(resolution.isApplied, isFalse);
      expect(resolution.offsetCandidate, isNull);
      expect(resolution.decisionReason, 'disabled_by_contract');
    },
  );

  test(
    'squat calibration exposes correction without changing technique acceptance',
    () {
      final config = buildSquatConfig();

      final resolution = resolver.resolve(
        analysisKind: 'rangeRep',
        config: config,
        baseThreshold: config.formThreshold,
        formThresholdCalibrationPolicy:
            RangeRepContracts.squat.formThresholdCalibrationPolicy,
        sessionCalibrationBaseline: const SessionCalibrationBaseline(
          analysisKind: 'rangeRep',
          sampleCount: 3,
          selectedSideLabel: 'left',
          formMetricBaseline: 52.0,
        ),
        selectedRangeRepSide: 'left',
      );

      expect(resolution.isApplied, isFalse);
      expect(resolution.offsetCandidate, 5.0);
      expect(resolution.effectiveThreshold, config.formThreshold);
      expect(resolution.decisionReason, 'measurement_correction_only');
    },
  );

  test(
    'push-up calibration exposes correction without changing technique acceptance',
    () {
      final config = loadExerciseConfig('assets/config/exercises/push_up.json');

      final resolution = resolver.resolve(
        analysisKind: 'rangeRep',
        config: config,
        baseThreshold: config.formThreshold,
        formThresholdCalibrationPolicy:
            RangeRepContracts.pushUp.formThresholdCalibrationPolicy,
        sessionCalibrationBaseline: const SessionCalibrationBaseline(
          analysisKind: 'rangeRep',
          sampleCount: 3,
          selectedSideLabel: 'left',
          formMetricBaseline: 155.0,
        ),
        selectedRangeRepSide: 'left',
      );

      expect(resolution.isApplied, isFalse);
      expect(resolution.offsetCandidate, 5.0);
      expect(resolution.effectiveThreshold, config.formThreshold);
      expect(resolution.decisionReason, 'measurement_correction_only');
    },
  );
}
