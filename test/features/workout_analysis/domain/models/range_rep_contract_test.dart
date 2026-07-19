import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/analysis_signal_role.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/range_rep_contract.dart';

const Set<AnalysisSignalRole> _primaryMetricRoles = <AnalysisSignalRole>{
  AnalysisSignalRole.detection,
  AnalysisSignalRole.validation,
  AnalysisSignalRole.scoring,
};
const Set<AnalysisSignalRole> _formMetricRoles = <AnalysisSignalRole>{
  AnalysisSignalRole.validation,
  AnalysisSignalRole.technique,
  AnalysisSignalRole.scoring,
};
const Set<AnalysisSignalRole> _techniqueRoles = <AnalysisSignalRole>{
  AnalysisSignalRole.technique,
};
const Set<AnalysisSignalRole> _scoringRoles = <AnalysisSignalRole>{
  AnalysisSignalRole.scoring,
};

void main() {
  group('RangeRepContract role metadata', () {
    test('deeply copies and protects role metadata', () {
      final primaryRoles = <AnalysisSignalRole>{AnalysisSignalRole.detection};
      final source = <RangeRepSignal, Set<AnalysisSignalRole>>{
        RangeRepSignal.primaryMetric: primaryRoles,
      };
      final contract = RangeRepContract(
        supportedPhases: const <RangeRepPhase>{RangeRepPhase.descending},
        supportedSignals: const <RangeRepSignal>{RangeRepSignal.primaryMetric},
        signalRoles: source,
      );

      primaryRoles.add(AnalysisSignalRole.scoring);
      source[RangeRepSignal.formMetric] = <AnalysisSignalRole>{
        AnalysisSignalRole.technique,
      };

      expect(
        contract.rolesForSignal(RangeRepSignal.primaryMetric),
        <AnalysisSignalRole>{AnalysisSignalRole.detection},
      );
      expect(contract.rolesForSignal(RangeRepSignal.formMetric), isEmpty);
      expect(
        () => contract.signalRoles[RangeRepSignal.formMetric] =
            const <AnalysisSignalRole>{AnalysisSignalRole.technique},
        throwsUnsupportedError,
      );
      expect(
        () => contract
            .rolesForSignal(RangeRepSignal.primaryMetric)
            .add(AnalysisSignalRole.scoring),
        throwsUnsupportedError,
      );
    });

    test('rejects missing and empty roles for supported signals', () {
      expect(
        () => RangeRepContract(
          supportedPhases: const <RangeRepPhase>{RangeRepPhase.descending},
          supportedSignals: const <RangeRepSignal>{
            RangeRepSignal.primaryMetric,
          },
          signalRoles: const <RangeRepSignal, Set<AnalysisSignalRole>>{},
        ),
        throwsArgumentError,
      );
      expect(
        () => RangeRepContract(
          supportedPhases: const <RangeRepPhase>{RangeRepPhase.descending},
          supportedSignals: const <RangeRepSignal>{
            RangeRepSignal.primaryMetric,
          },
          signalRoles: const <RangeRepSignal, Set<AnalysisSignalRole>>{
            RangeRepSignal.primaryMetric: <AnalysisSignalRole>{},
          },
        ),
        throwsArgumentError,
      );
    });

    test('rejects role keys outside supported signals', () {
      expect(
        () => RangeRepContract(
          supportedPhases: const <RangeRepPhase>{RangeRepPhase.descending},
          supportedSignals: const <RangeRepSignal>{
            RangeRepSignal.primaryMetric,
          },
          signalRoles: const <RangeRepSignal, Set<AnalysisSignalRole>>{
            RangeRepSignal.primaryMetric: <AnalysisSignalRole>{
              AnalysisSignalRole.detection,
            },
            RangeRepSignal.formMetric: <AnalysisSignalRole>{
              AnalysisSignalRole.technique,
            },
          },
        ),
        throwsArgumentError,
      );
    });

    test('keeps pose acceptance independent from semantic roles', () {
      final contract = RangeRepContract(
        supportedPhases: const <RangeRepPhase>{RangeRepPhase.descending},
        supportedSignals: const <RangeRepSignal>{
          RangeRepSignal.primaryMetric,
          RangeRepSignal.formMetric,
        },
        poseAcceptanceRequiredSignals: const <RangeRepSignal>{
          RangeRepSignal.primaryMetric,
        },
        signalRoles: const <RangeRepSignal, Set<AnalysisSignalRole>>{
          RangeRepSignal.primaryMetric: _primaryMetricRoles,
          RangeRepSignal.formMetric: _formMetricRoles,
        },
      );

      expect(
        contract.requiresPoseAcceptanceSignal(RangeRepSignal.primaryMetric),
        isTrue,
      );
      expect(
        contract.requiresPoseAcceptanceSignal(RangeRepSignal.formMetric),
        isFalse,
      );
      expect(
        contract.signalHasRole(
          RangeRepSignal.formMetric,
          AnalysisSignalRole.validation,
        ),
        isTrue,
      );
      expect(
        contract.signalsForRole(AnalysisSignalRole.detection),
        <RangeRepSignal>{RangeRepSignal.primaryMetric},
      );
    });

    test('pose-acceptance signals must stay within supported signals', () {
      expect(
        () => RangeRepContract(
          supportedPhases: const <RangeRepPhase>{RangeRepPhase.descending},
          supportedSignals: const <RangeRepSignal>{
            RangeRepSignal.primaryMetric,
          },
          poseAcceptanceRequiredSignals: const <RangeRepSignal>{
            RangeRepSignal.formMetric,
          },
          signalRoles: const <RangeRepSignal, Set<AnalysisSignalRole>>{
            RangeRepSignal.primaryMetric: <AnalysisSignalRole>{
              AnalysisSignalRole.detection,
            },
          },
        ),
        throwsArgumentError,
      );
    });
  });

  group('predefined range-rep role classifications', () {
    test('Squat declares current roles for every supported signal', () {
      _expectExtendedRangeRepRoles(RangeRepContracts.squat);
    });

    test('Push-up declares current roles for every supported signal', () {
      _expectExtendedRangeRepRoles(RangeRepContracts.pushUp);
    });

    test('Sit-up keeps formMetric technique-owned and not setup-owned', () {
      final contract = RangeRepContracts.sitUp;

      expect(
        contract.rolesForSignal(RangeRepSignal.primaryMetric),
        _primaryMetricRoles,
      );
      expect(
        contract.rolesForSignal(RangeRepSignal.formMetric),
        _formMetricRoles,
      );
      expect(
        contract.rolesForSignal(RangeRepSignal.postureAngle),
        _techniqueRoles,
      );
      expect(
        contract.rolesForSignal(RangeRepSignal.depthMetric),
        _scoringRoles,
      );
      expect(
        contract.signalHasRole(
          RangeRepSignal.formMetric,
          AnalysisSignalRole.setup,
        ),
        isFalse,
      );
      expect(
        contract.formThresholdCalibrationPolicy,
        RangeRepFormThresholdCalibrationPolicy.disabled,
      );
    });

    test('bilateral Biceps declares current non-ROM-delta roles', () {
      final contract = RangeRepContracts.bicepsCurl;

      expect(
        contract.rolesForSignal(RangeRepSignal.primaryMetric),
        _primaryMetricRoles,
      );
      expect(
        contract.rolesForSignal(RangeRepSignal.formMetric),
        _formMetricRoles,
      );
      expect(
        contract.rolesForSignal(RangeRepSignal.postureAngle),
        _techniqueRoles,
      );
      expect(
        contract.rolesForSignal(RangeRepSignal.depthMetric),
        _scoringRoles,
      );
      expect(contract.sideMode, RangeRepSideMode.bilateral);
    });
  });
}

void _expectExtendedRangeRepRoles(RangeRepContract contract) {
  expect(
    contract.rolesForSignal(RangeRepSignal.primaryMetric),
    _primaryMetricRoles,
  );
  expect(contract.rolesForSignal(RangeRepSignal.formMetric), _formMetricRoles);
  expect(contract.rolesForSignal(RangeRepSignal.postureAngle), _techniqueRoles);
  expect(contract.rolesForSignal(RangeRepSignal.depthMetric), _scoringRoles);
  expect(
    contract.rolesForSignal(RangeRepSignal.alignmentMetric),
    _techniqueRoles,
  );
  expect(
    contract.rolesForSignal(RangeRepSignal.endRangeMetric),
    _techniqueRoles,
  );
  expect(contract.signalRoles.keys.toSet(), contract.supportedSignals);
}
