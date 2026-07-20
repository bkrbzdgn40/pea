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
  hipDeviation,
  shoulderElbowOffset,
}

/// Immutable contract describing which normalized signals a hold exercise
/// supports and which of those signals are required for pose acceptance.
class HoldContract {
  HoldContract({
    required this.family,
    required Iterable<HoldSignal> requiredSignals,
    Iterable<HoldSignal>? supportedSignals,
    required Map<HoldSignal, Set<AnalysisSignalRole>> signalRoles,
  }) : requiredSignals = Set<HoldSignal>.unmodifiable(requiredSignals),
       supportedSignals = Set<HoldSignal>.unmodifiable(
         supportedSignals ?? requiredSignals,
       ),
       signalRoles = Map<HoldSignal, Set<AnalysisSignalRole>>.unmodifiable(
         <HoldSignal, Set<AnalysisSignalRole>>{
           for (final signal in HoldSignal.values)
             if (signalRoles.containsKey(signal))
               signal: Set<AnalysisSignalRole>.unmodifiable(
                 AnalysisSignalRole.values.where(signalRoles[signal]!.contains),
               ),
         },
       ) {
    final unsupportedRequiredSignals = this.requiredSignals.difference(
      this.supportedSignals,
    );
    if (unsupportedRequiredSignals.isNotEmpty) {
      throw ArgumentError.value(
        unsupportedRequiredSignals,
        'requiredSignals',
        'Required signals must be a subset of supportedSignals.',
      );
    }

    final missingRoleSignals = this.supportedSignals.where(
      (signal) => rolesForSignal(signal).isEmpty,
    );
    if (missingRoleSignals.isNotEmpty) {
      throw ArgumentError.value(
        missingRoleSignals.toSet(),
        'signalRoles',
        'Every supported signal must have at least one semantic role.',
      );
    }

    final unsupportedRoleSignals = this.signalRoles.keys.toSet().difference(
      this.supportedSignals,
    );
    if (unsupportedRoleSignals.isNotEmpty) {
      throw ArgumentError.value(
        unsupportedRoleSignals,
        'signalRoles',
        'Role metadata may only describe supported signals.',
      );
    }
  }

  final HoldAnalysisFamily family;

  /// Signals that must be available for the existing hold acceptance path.
  final Set<HoldSignal> requiredSignals;

  /// Signals the analysis family can produce, including diagnostic/technique
  /// signals that are not hard pose-acceptance requirements.
  final Set<HoldSignal> supportedSignals;

  final Map<HoldSignal, Set<AnalysisSignalRole>> signalRoles;

  bool supportsSignal(HoldSignal signal) {
    return supportedSignals.contains(signal);
  }

  Set<AnalysisSignalRole> rolesForSignal(HoldSignal signal) {
    return signalRoles[signal] ?? const <AnalysisSignalRole>{};
  }

  bool signalHasRole(HoldSignal signal, AnalysisSignalRole role) {
    return rolesForSignal(signal).contains(role);
  }

  Set<HoldSignal> signalsForRole(AnalysisSignalRole role) {
    return Set<HoldSignal>.unmodifiable(
      supportedSignals.where((signal) => signalHasRole(signal, role)),
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
    supportedSignals: const <HoldSignal>{
      HoldSignal.alignment,
      HoldSignal.support,
      HoldSignal.extension,
      HoldSignal.hipDeviation,
      HoldSignal.shoulderElbowOffset,
    },
    signalRoles: const <HoldSignal, Set<AnalysisSignalRole>>{
      HoldSignal.alignment: <AnalysisSignalRole>{
        AnalysisSignalRole.detection,
        AnalysisSignalRole.validation,
      },
      HoldSignal.support: <AnalysisSignalRole>{
        AnalysisSignalRole.detection,
        AnalysisSignalRole.validation,
      },
      HoldSignal.extension: <AnalysisSignalRole>{
        AnalysisSignalRole.detection,
        AnalysisSignalRole.validation,
        AnalysisSignalRole.technique,
      },
      HoldSignal.hipDeviation: <AnalysisSignalRole>{
        AnalysisSignalRole.technique,
      },
      HoldSignal.shoulderElbowOffset: <AnalysisSignalRole>{
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
