import 'analysis_signal_role.dart';

enum HoldAnalysisFamily { plank, hollowHold }

/// Canonical signal identifiers that a hold contract may support.
enum HoldSignal {
  alignment,
  support,
  extension,
  compression,
  armExtension,
  kneeExtension,
}

/// Immutable contract describing which normalized signals a hold exercise
/// supports.
class HoldContract {
  HoldContract({
    required this.family,
    required Iterable<HoldSignal> requiredSignals,
    required Map<HoldSignal, Set<AnalysisSignalRole>> signalRoles,
  }) : requiredSignals = Set<HoldSignal>.unmodifiable(requiredSignals),
       signalRoles = Map<HoldSignal, Set<AnalysisSignalRole>>.unmodifiable(
         <HoldSignal, Set<AnalysisSignalRole>>{
           for (final signal in HoldSignal.values)
             if (signalRoles.containsKey(signal))
               signal: Set<AnalysisSignalRole>.unmodifiable(
                 AnalysisSignalRole.values.where(signalRoles[signal]!.contains),
               ),
         },
       ) {
    final missingRoleSignals = this.requiredSignals.where(
      (signal) => rolesForSignal(signal).isEmpty,
    );
    if (missingRoleSignals.isNotEmpty) {
      throw ArgumentError.value(
        missingRoleSignals.toSet(),
        'signalRoles',
        'Every required signal must have at least one semantic role.',
      );
    }

    final unsupportedRoleSignals = this.signalRoles.keys.toSet().difference(
      this.requiredSignals,
    );
    if (unsupportedRoleSignals.isNotEmpty) {
      throw ArgumentError.value(
        unsupportedRoleSignals,
        'signalRoles',
        'Role metadata may only describe required signals.',
      );
    }
  }

  final HoldAnalysisFamily family;

  final Set<HoldSignal> requiredSignals;
  final Map<HoldSignal, Set<AnalysisSignalRole>> signalRoles;

  bool supportsSignal(HoldSignal signal) {
    return requiredSignals.contains(signal);
  }

  Set<AnalysisSignalRole> rolesForSignal(HoldSignal signal) {
    return signalRoles[signal] ?? const <AnalysisSignalRole>{};
  }

  bool signalHasRole(HoldSignal signal, AnalysisSignalRole role) {
    return rolesForSignal(signal).contains(role);
  }

  Set<HoldSignal> signalsForRole(AnalysisSignalRole role) {
    return Set<HoldSignal>.unmodifiable(
      HoldSignal.values.where((signal) => signalHasRole(signal, role)),
    );
  }
}

/// Predefined hold contracts kept separate from runtime wiring.
abstract final class HoldContracts {
  static final HoldContract plankFamily = HoldContract(
    family: HoldAnalysisFamily.plank,
    requiredSignals: const <HoldSignal>{
      HoldSignal.alignment,
      HoldSignal.support,
      HoldSignal.extension,
    },
    signalRoles: const <HoldSignal, Set<AnalysisSignalRole>>{
      HoldSignal.alignment: <AnalysisSignalRole>{
        AnalysisSignalRole.detection,
        AnalysisSignalRole.validation,
        AnalysisSignalRole.technique,
      },
      HoldSignal.support: <AnalysisSignalRole>{
        AnalysisSignalRole.detection,
        AnalysisSignalRole.validation,
        AnalysisSignalRole.technique,
      },
      HoldSignal.extension: <AnalysisSignalRole>{
        AnalysisSignalRole.detection,
        AnalysisSignalRole.validation,
        AnalysisSignalRole.technique,
      },
    },
  );

  static final HoldContract hollowHold = HoldContract(
    family: HoldAnalysisFamily.hollowHold,
    requiredSignals: const <HoldSignal>{
      HoldSignal.compression,
      HoldSignal.armExtension,
      HoldSignal.kneeExtension,
    },
    signalRoles: const <HoldSignal, Set<AnalysisSignalRole>>{
      HoldSignal.compression: <AnalysisSignalRole>{
        AnalysisSignalRole.detection,
      },
      HoldSignal.armExtension: <AnalysisSignalRole>{
        AnalysisSignalRole.detection,
        AnalysisSignalRole.validation,
        AnalysisSignalRole.technique,
      },
      HoldSignal.kneeExtension: <AnalysisSignalRole>{
        AnalysisSignalRole.detection,
        AnalysisSignalRole.validation,
        AnalysisSignalRole.technique,
      },
    },
  );
}
