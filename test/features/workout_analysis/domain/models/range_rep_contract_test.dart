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
const Set<AnalysisSignalRole> _setupRoles = <AnalysisSignalRole>{
  AnalysisSignalRole.setup,
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

    test('Sit-up classifies knee-angle carriers as setup-only', () {
      final contract = RangeRepContracts.sitUp;

      expect(
        contract.rolesForSignal(RangeRepSignal.primaryMetric),
        _primaryMetricRoles,
      );
      expect(contract.rolesForSignal(RangeRepSignal.formMetric), _setupRoles);
      expect(contract.rolesForSignal(RangeRepSignal.postureAngle), _setupRoles);
      expect(
        contract.rolesForSignal(RangeRepSignal.depthMetric),
        _scoringRoles,
      );
      for (final role in const <AnalysisSignalRole>{
        AnalysisSignalRole.detection,
        AnalysisSignalRole.validation,
        AnalysisSignalRole.technique,
        AnalysisSignalRole.scoring,
      }) {
        expect(
          contract.signalHasRole(RangeRepSignal.formMetric, role),
          isFalse,
        );
      }
      expect(
        contract.signalHasRole(
          RangeRepSignal.postureAngle,
          AnalysisSignalRole.technique,
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
      expect(
        contract.bilateralFormPolicy,
        RangeRepBilateralFormPolicy.sideFormOnly,
      );
    });

    test(
      'Romanian Deadlift keeps knee-form technique optional for pose acceptance',
      () {
        final contract = RangeRepContracts.romanianDeadlift;

        expect(contract.poseAcceptanceRequiredSignals, <RangeRepSignal>{
          RangeRepSignal.primaryMetric,
        });
        expect(
          contract.signalHasRole(
            RangeRepSignal.formMetric,
            AnalysisSignalRole.technique,
          ),
          isTrue,
        );
        expect(
          contract.requiresPoseAcceptanceSignal(RangeRepSignal.formMetric),
          isFalse,
        );
      },
    );

    test('Lateral Raise keeps sync out of elbow-form feedback', () {
      final contract = RangeRepContracts.lateralRaise;

      expect(contract.sideMode, RangeRepSideMode.bilateral);
      expect(
        contract.bilateralFormPolicy,
        RangeRepBilateralFormPolicy.sideFormOnly,
      );
    });

    test('Jumping Jack declares device-proven bilateral signal semantics', () {
      final contract = RangeRepContracts.jumpingJack;

      expect(
        contract.bilateralPrimaryPolicy,
        RangeRepBilateralPrimaryPolicy.mean,
      );
      expect(
        contract.techniqueEvaluationPolicy,
        RangeRepTechniqueEvaluationPolicy.peakWindowOnly,
      );
      expect(contract.peakEntryMargin, 0.0);
      expect(
        contract.shouldEvaluateTechnique(
          primaryMetric: 15,
          activeThreshold: 55,
          peakThreshold: 120,
        ),
        isFalse,
      );
      expect(
        contract.shouldEvaluateTechnique(
          primaryMetric: 100,
          activeThreshold: 55,
          peakThreshold: 120,
        ),
        isFalse,
      );
      expect(
        contract.shouldEvaluateTechnique(
          primaryMetric: 125,
          activeThreshold: 55,
          peakThreshold: 120,
        ),
        isTrue,
      );
    });

    test('sparse cycle recovery is limited to device-proven blockers', () {
      for (final contract in <RangeRepContract>[
        RangeRepContracts.tricepsDip,
        RangeRepContracts.jumpingJack,
      ]) {
        expect(contract.retainPeakEvidenceAcrossActiveTransition, isTrue);
        expect(contract.allowSparseCycleRecovery, isTrue);
        expect(contract.primaryMetricSmoothingWindow, 1);
      }
      expect(RangeRepContracts.tricepsDip.formMetricSmoothingWindow, 5);
      expect(RangeRepContracts.jumpingJack.formMetricSmoothingWindow, 1);

      for (final contract in <RangeRepContract>[
        RangeRepContracts.squat,
        RangeRepContracts.pushUp,
        RangeRepContracts.sitUp,
      ]) {
        expect(contract.retainPeakEvidenceAcrossActiveTransition, isFalse);
        expect(contract.allowSparseCycleRecovery, isFalse);
        expect(contract.primaryMetricSmoothingWindow, 5);
        expect(contract.formMetricSmoothingWindow, 5);
      }
    });

    test('rejects a non-positive primary metric smoothing window', () {
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
          },
          primaryMetricSmoothingWindow: 0,
        ),
        throwsArgumentError,
      );
    });

    test('rejects a non-positive form metric smoothing window', () {
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
          },
          formMetricSmoothingWindow: 0,
        ),
        throwsArgumentError,
      );
    });

    test(
      'Day 11 dynamic exercises declare intentional direction and side mode',
      () {
        for (final contract in <RangeRepContract>[
          RangeRepContracts.calfRaise,
          RangeRepContracts.frontRaise,
          RangeRepContracts.gluteBridge,
          RangeRepContracts.jumpingJack,
        ]) {
          expect(
            contract.primaryMetricDirection,
            RangeRepPrimaryMetricDirection.increasingToPeak,
          );
          expect(
            contract.towardPeakMuscleAction,
            RangeRepTowardPeakMuscleAction.concentric,
          );
        }

        expect(
          RangeRepContracts.jumpingJack.sideMode,
          RangeRepSideMode.bilateral,
        );
        expect(
          RangeRepContracts.frontRaise.sideMode,
          RangeRepSideMode.selectedSide,
        );
        expect(
          RangeRepContracts.gluteBridge.signalHasRole(
            RangeRepSignal.formMetric,
            AnalysisSignalRole.technique,
          ),
          isFalse,
        );
        expect(
          RangeRepContracts.jumpingJack.signalHasRole(
            RangeRepSignal.formMetric,
            AnalysisSignalRole.technique,
          ),
          isTrue,
        );
      },
    );
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
