import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/range_rep_threshold_bookkeeper.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/range_rep_contract.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/session_calibration_baseline.dart';

import '../../../support/workout_analysis_test_support.dart';

void main() {
  test(
    'sit-up bookkeeper reports disabled_by_contract without applying a calibration offset',
    () {
      final config = loadExerciseConfig('assets/config/exercises/sit_up.json');
      final bookkeeper = RangeRepThresholdBookkeeper(
        analysisKind: 'rangeRep',
        config: config,
        formThresholdCalibrationPolicy:
            RangeRepContracts.sitUp.formThresholdCalibrationPolicy,
      );

      final resolution = bookkeeper.resolve(
        baseThreshold: config.formThreshold,
        sessionCalibrationBaseline: const SessionCalibrationBaseline(
          analysisKind: 'rangeRep',
          sampleCount: 3,
          selectedSideLabel: 'left',
          formMetricBaseline: 120.0,
        ),
        selectedRangeRepSide: 'left',
      );

      expect(resolution.effectiveThreshold, 60.0);
      expect(resolution.isApplied, isFalse);
      expect(resolution.decisionReason, 'disabled_by_contract');
      expect(bookkeeper.decisionCount, 1);
      expect(bookkeeper.appliedCount, 0);
      expect(bookkeeper.noBaselineCount, 0);
      expect(bookkeeper.offsetTooSmallCount, 0);
    },
  );

  test(
    'squat bookkeeper records correction candidate without applying threshold',
    () {
      final config = buildSquatConfig();
      final bookkeeper = RangeRepThresholdBookkeeper(
        analysisKind: 'rangeRep',
        config: config,
        formThresholdCalibrationPolicy:
            RangeRepContracts.squat.formThresholdCalibrationPolicy,
      );

      final resolution = bookkeeper.resolve(
        baseThreshold: config.formThreshold,
        sessionCalibrationBaseline: const SessionCalibrationBaseline(
          analysisKind: 'rangeRep',
          sampleCount: 3,
          selectedSideLabel: 'left',
          formMetricBaseline: 52.0,
        ),
        selectedRangeRepSide: 'left',
      );

      expect(resolution.effectiveThreshold, config.formThreshold);
      expect(resolution.isApplied, isFalse);
      expect(resolution.offsetCandidate, 5.0);
      expect(resolution.decisionReason, 'measurement_correction_only');
      expect(bookkeeper.decisionCount, 1);
      expect(bookkeeper.appliedCount, 0);
    },
  );
}
