import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/analysis_signal_role.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_contract.dart';

const Set<AnalysisSignalRole> _legacyHoldRoles = <AnalysisSignalRole>{
  AnalysisSignalRole.detection,
  AnalysisSignalRole.validation,
  AnalysisSignalRole.technique,
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

    test('separates supported signals from hard required signals', () {
      final contract = HoldContract(
        family: HoldAnalysisFamily.plank,
        requiredSignals: const <HoldSignal>{HoldSignal.alignment},
        supportedSignals: const <HoldSignal>{
          HoldSignal.alignment,
          HoldSignal.hipDeviation,
        },
        signalRoles: const <HoldSignal, Set<AnalysisSignalRole>>{
          HoldSignal.alignment: <AnalysisSignalRole>{
            AnalysisSignalRole.validation,
          },
          HoldSignal.hipDeviation: <AnalysisSignalRole>{
            AnalysisSignalRole.technique,
          },
        },
      );

      expect(contract.requiredSignals, const <HoldSignal>{HoldSignal.alignment});
      expect(contract.supportsSignal(HoldSignal.hipDeviation), isTrue);
      expect(
        contract.signalsForRole(AnalysisSignalRole.technique),
        const <HoldSignal>{HoldSignal.hipDeviation},
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
      expect(
        () => HoldContract(
          family: HoldAnalysisFamily.plank,
          requiredSignals: const <HoldSignal>{
            HoldSignal.alignment,
            HoldSignal.hipDeviation,
          },
          supportedSignals: const <HoldSignal>{HoldSignal.alignment},
          signalRoles: const <HoldSignal, Set<AnalysisSignalRole>>{
            HoldSignal.alignment: <AnalysisSignalRole>{
              AnalysisSignalRole.detection,
            },
          },
        ),
        throwsArgumentError,
      );
    });
  });

  group('predefined hold role classifications', () {
    test('Plank uses hip deviation as its primary technique measurement', () {
      final contract = HoldContracts.plankFamily;

      expect(contract.requiredSignals, const <HoldSignal>{
        HoldSignal.alignment,
        HoldSignal.support,
        HoldSignal.extension,
      });
      expect(contract.supportedSignals, const <HoldSignal>{
        HoldSignal.alignment,
        HoldSignal.support,
        HoldSignal.extension,
        HoldSignal.hipDeviation,
      });
      expect(
        contract.rolesForSignal(HoldSignal.alignment),
        const <AnalysisSignalRole>{
          AnalysisSignalRole.detection,
          AnalysisSignalRole.validation,
        },
      );
      expect(
        contract.rolesForSignal(HoldSignal.hipDeviation),
        const <AnalysisSignalRole>{AnalysisSignalRole.technique},
      );
      expect(
        contract.signalsForRole(AnalysisSignalRole.technique),
        const <HoldSignal>{
          HoldSignal.support,
          HoldSignal.extension,
          HoldSignal.hipDeviation,
        },
      );
    });

    test(
      'Hollow compression is detection-only while limb signals keep legacy roles',
      () {
        final contract = HoldContracts.hollowHold;

        expect(contract.requiredSignals, const <HoldSignal>{
          HoldSignal.compression,
          HoldSignal.armExtension,
          HoldSignal.kneeExtension,
        });
        expect(contract.supportedSignals, contract.requiredSignals);
        expect(contract.signalRoles.keys.toSet(), contract.requiredSignals);
        expect(
          contract.rolesForSignal(HoldSignal.compression),
          const <AnalysisSignalRole>{AnalysisSignalRole.detection},
        );
        expect(
          contract.signalHasRole(
            HoldSignal.compression,
            AnalysisSignalRole.validation,
          ),
          isFalse,
        );
        expect(
          contract.signalHasRole(
            HoldSignal.compression,
            AnalysisSignalRole.technique,
          ),
          isFalse,
        );
        expect(
          contract.rolesForSignal(HoldSignal.armExtension),
          _legacyHoldRoles,
        );
        expect(
          contract.rolesForSignal(HoldSignal.kneeExtension),
          _legacyHoldRoles,
        );
        expect(
          contract.signalHasRole(
            HoldSignal.compression,
            AnalysisSignalRole.setup,
          ),
          isFalse,
        );
        expect(
          contract.signalHasRole(
            HoldSignal.compression,
            AnalysisSignalRole.scoring,
          ),
          isFalse,
        );
      },
    );
  });
}
