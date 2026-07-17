import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/range_rep_contract.dart';

void main() {
  test(
    'RangeRepContract defaults form-threshold calibration policy to enabled',
    () {
      final contract = RangeRepContract(
        supportedPhases: const <RangeRepPhase>{RangeRepPhase.descending},
        supportedSignals: const <RangeRepSignal>{RangeRepSignal.primaryMetric},
      );

      expect(
        contract.formThresholdCalibrationPolicy,
        RangeRepFormThresholdCalibrationPolicy.enabled,
      );
    },
  );

  test('RangeRepContracts.sitUp exposes the mandatory phases and signals', () {
    final contract = RangeRepContracts.sitUp;

    expect(
      contract.supportedPhases,
      containsAll(<RangeRepPhase>[
        RangeRepPhase.descending,
        RangeRepPhase.peak,
        RangeRepPhase.ascending,
      ]),
    );
    expect(
      contract.supportedSignals,
      containsAll(<RangeRepSignal>[
        RangeRepSignal.primaryMetric,
        RangeRepSignal.formMetric,
        RangeRepSignal.postureAngle,
        RangeRepSignal.depthMetric,
      ]),
    );
    expect(contract.supportsSignal(RangeRepSignal.alignmentMetric), isFalse);
    expect(contract.supportsSignal(RangeRepSignal.endRangeMetric), isFalse);
    expect(contract.poseAcceptanceRequiredSignals, <RangeRepSignal>{
      RangeRepSignal.primaryMetric,
    });
  });

  test(
    'RangeRepContracts.bicepsCurl exposes bilateral range-rep semantics',
    () {
      final contract = RangeRepContracts.bicepsCurl;

      expect(
        contract.supportedPhases,
        containsAll(<RangeRepPhase>[
          RangeRepPhase.descending,
          RangeRepPhase.peak,
          RangeRepPhase.ascending,
        ]),
      );
      expect(
        contract.supportedSignals,
        containsAll(<RangeRepSignal>[
          RangeRepSignal.primaryMetric,
          RangeRepSignal.formMetric,
          RangeRepSignal.postureAngle,
          RangeRepSignal.depthMetric,
        ]),
      );
      expect(contract.sideMode, RangeRepSideMode.bilateral);
      expect(contract.poseAcceptanceRequiredSignals, <RangeRepSignal>{
        RangeRepSignal.primaryMetric,
        RangeRepSignal.formMetric,
      });
      expect(
        contract.formThresholdCalibrationPolicy,
        RangeRepFormThresholdCalibrationPolicy.disabled,
      );
    },
  );

  test('RangeRepContracts.squat keeps threshold calibration enabled', () {
    expect(
      RangeRepContracts.squat.formThresholdCalibrationPolicy,
      RangeRepFormThresholdCalibrationPolicy.enabled,
    );
  });

  test('RangeRepContracts.pushUp keeps threshold calibration enabled', () {
    expect(
      RangeRepContracts.pushUp.formThresholdCalibrationPolicy,
      RangeRepFormThresholdCalibrationPolicy.enabled,
    );
  });

  test('RangeRepContracts.sitUp disables threshold calibration', () {
    expect(
      RangeRepContracts.sitUp.formThresholdCalibrationPolicy,
      RangeRepFormThresholdCalibrationPolicy.disabled,
    );
  });

  test('existing selected-side contracts keep their side mode unchanged', () {
    expect(RangeRepContracts.squat.sideMode, RangeRepSideMode.selectedSide);
    expect(RangeRepContracts.pushUp.sideMode, RangeRepSideMode.selectedSide);
    expect(RangeRepContracts.sitUp.sideMode, RangeRepSideMode.selectedSide);
  });

  test(
    'squat and push-up keep pose-acceptance requirements aligned with supported signals',
    () {
      expect(
        RangeRepContracts.squat.poseAcceptanceRequiredSignals,
        RangeRepContracts.squat.supportedSignals,
      );
      expect(
        RangeRepContracts.pushUp.poseAcceptanceRequiredSignals,
        RangeRepContracts.pushUp.supportedSignals,
      );
    },
  );

  test('pose-acceptance signals must stay within supported signals', () {
    expect(
      () => RangeRepContract(
        supportedPhases: const <RangeRepPhase>{RangeRepPhase.descending},
        supportedSignals: const <RangeRepSignal>{RangeRepSignal.primaryMetric},
        poseAcceptanceRequiredSignals: const <RangeRepSignal>{
          RangeRepSignal.formMetric,
        },
      ),
      throwsArgumentError,
    );
  });
}
