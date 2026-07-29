import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/analysis_signal_role.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_contract.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hollow_hold_variation.dart';

const Set<AnalysisSignalRole> _plankLegacyGateRoles = <AnalysisSignalRole>{
  AnalysisSignalRole.detection,
  AnalysisSignalRole.validation,
};

const Set<AnalysisSignalRole> _hollowSetupValidationRoles =
    <AnalysisSignalRole>{
      AnalysisSignalRole.setup,
      AnalysisSignalRole.validation,
    };

void main() {
  group('HoldContract role metadata', () {
    test('deeply copies and protects role metadata', () {
      final alignmentRoles = <AnalysisSignalRole>{AnalysisSignalRole.detection};
      final source = <HoldSignal, Set<AnalysisSignalRole>>{
        HoldSignal.alignment: alignmentRoles,
      };
      final contract = HoldContract(
        family: HoldAnalysisFamily.plank,
        requiredSignals: const <HoldSignal>{HoldSignal.alignment},
        signalRoles: source,
      );

      alignmentRoles.add(AnalysisSignalRole.technique);
      source[HoldSignal.support] = <AnalysisSignalRole>{
        AnalysisSignalRole.detection,
      };

      expect(
        contract.rolesForSignal(HoldSignal.alignment),
        <AnalysisSignalRole>{AnalysisSignalRole.detection},
      );
      expect(contract.rolesForSignal(HoldSignal.support), isEmpty);
      expect(
        () => contract.signalRoles[HoldSignal.support] =
            const <AnalysisSignalRole>{AnalysisSignalRole.detection},
        throwsUnsupportedError,
      );
      expect(
        () => contract
            .rolesForSignal(HoldSignal.alignment)
            .add(AnalysisSignalRole.technique),
        throwsUnsupportedError,
      );
    });

    test('rejects missing roles and unsupported role keys', () {
      expect(
        () => HoldContract(
          family: HoldAnalysisFamily.plank,
          requiredSignals: const <HoldSignal>{HoldSignal.alignment},
          signalRoles: const <HoldSignal, Set<AnalysisSignalRole>>{},
        ),
        throwsArgumentError,
      );
      expect(
        () => HoldContract(
          family: HoldAnalysisFamily.plank,
          requiredSignals: const <HoldSignal>{HoldSignal.alignment},
          signalRoles: const <HoldSignal, Set<AnalysisSignalRole>>{
            HoldSignal.alignment: <AnalysisSignalRole>{
              AnalysisSignalRole.detection,
            },
            HoldSignal.support: <AnalysisSignalRole>{
              AnalysisSignalRole.detection,
            },
          },
        ),
        throwsArgumentError,
      );
    });

    test('requires explicit Hollow Hold variation ownership', () {
      expect(
        () => HoldContract(
          family: HoldAnalysisFamily.hollowHold,
          requiredSignals: const <HoldSignal>{HoldSignal.compression},
          signalRoles: const <HoldSignal, Set<AnalysisSignalRole>>{
            HoldSignal.compression: <AnalysisSignalRole>{
              AnalysisSignalRole.detection,
            },
          },
        ),
        throwsArgumentError,
      );
    });
  });

  group('predefined hold role classifications', () {
    test('Plank legacy angle signals are no longer technique-role signals', () {
      final contract = HoldContracts.plankFamily;
      expect(contract.requiredSignals, const <HoldSignal>{
        HoldSignal.alignment,
        HoldSignal.support,
        HoldSignal.extension,
      });
      expect(contract.signalRoles.keys.toSet(), contract.requiredSignals);
      for (final signal in contract.requiredSignals) {
        expect(contract.rolesForSignal(signal), _plankLegacyGateRoles);
        expect(
          contract.signalHasRole(signal, AnalysisSignalRole.technique),
          isFalse,
        );
      }
    });

    test('default Hollow Hold owns setup/validation by explicit variation', () {
      final contract = HoldContracts.hollowHold;

      expect(
        contract.hollowHoldVariation?.variation,
        HollowHoldVariation.straightLegOverhead,
      );
      expect(contract.requiredSignals, const <HoldSignal>{
        HoldSignal.compression,
        HoldSignal.armExtension,
        HoldSignal.kneeExtension,
      });
      expect(contract.signalRoles.keys.toSet(), contract.requiredSignals);
      expect(
        contract.rolesForSignal(HoldSignal.compression),
        const <AnalysisSignalRole>{
          AnalysisSignalRole.detection,
          AnalysisSignalRole.setup,
        },
      );
      expect(
        contract.rolesForSignal(HoldSignal.armExtension),
        _hollowSetupValidationRoles,
      );
      expect(
        contract.rolesForSignal(HoldSignal.kneeExtension),
        _hollowSetupValidationRoles,
      );
    });

    test('Side Plank reuses plank signals without plank family ownership', () {
      final contract = HoldContracts.sidePlank;

      expect(contract.family, HoldAnalysisFamily.sidePlank);
      expect(contract.requiredSignals, const <HoldSignal>{
        HoldSignal.alignment,
        HoldSignal.support,
        HoldSignal.extension,
      });
      expect(contract.supportsSignal(HoldSignal.supportStacking), isTrue);
      expect(contract.supportsSignal(HoldSignal.hipClearance), isTrue);
      expect(
        contract.rolesForSignal(HoldSignal.supportStacking),
        const <AnalysisSignalRole>{
          AnalysisSignalRole.detection,
          AnalysisSignalRole.validation,
        },
      );
      expect(
        contract.rolesForSignal(HoldSignal.hipClearance),
        const <AnalysisSignalRole>{
          AnalysisSignalRole.detection,
          AnalysisSignalRole.validation,
        },
      );
      for (final signal in contract.requiredSignals) {
        expect(
          contract.signalHasRole(signal, AnalysisSignalRole.technique),
          isFalse,
        );
      }
    });

    test('Wall Sit owns explicit knee, hip, and torso hold signals', () {
      final contract = HoldContracts.wallSit;

      expect(contract.family, HoldAnalysisFamily.wallSit);
      expect(contract.requiredSignals, const <HoldSignal>{
        HoldSignal.kneeFlexion,
        HoldSignal.hipFlexion,
        HoldSignal.torsoAlignment,
      });
      for (final signal in contract.requiredSignals) {
        expect(
          contract.signalHasRole(signal, AnalysisSignalRole.validation),
          isTrue,
        );
        expect(
          contract.signalHasRole(signal, AnalysisSignalRole.technique),
          isTrue,
        );
      }
    });

    test(
      'Hollow Hold variations require only their own validation signals',
      () {
        expect(
          HoldContracts.hollowHoldForVariation(
            HollowHoldVariation.tuck,
          ).requiredSignals,
          const <HoldSignal>{HoldSignal.compression},
        );
        expect(
          HoldContracts.hollowHoldForVariation(
            HollowHoldVariation.bentKnee,
          ).requiredSignals,
          const <HoldSignal>{HoldSignal.compression},
        );
        expect(
          HoldContracts.hollowHoldForVariation(
            HollowHoldVariation.straightLeg,
          ).requiredSignals,
          const <HoldSignal>{HoldSignal.compression, HoldSignal.kneeExtension},
        );
        expect(
          HoldContracts.hollowHoldForVariation(
            HollowHoldVariation.straightLegOverhead,
          ).requiredSignals,
          const <HoldSignal>{
            HoldSignal.compression,
            HoldSignal.armExtension,
            HoldSignal.kneeExtension,
          },
        );
      },
    );
  });
}
