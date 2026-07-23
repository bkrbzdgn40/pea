import 'analysis_signal_role.dart';
import 'hollow_hold_variation.dart';

enum HoldAnalysisFamily { plank, hollowHold, wallSit, sidePlank }

/// Canonical signal identifiers that a hold contract may support.
enum HoldSignal {
  alignment,
  support,
  supportStacking,
  extension,
  compression,
  armExtension,
  kneeExtension,
  kneeFlexion,
  hipFlexion,
  torsoAlignment,
}

/// Immutable contract describing which normalized signals a hold exercise
/// supports.
class HoldContract {
  HoldContract({
    required this.family,
    required Iterable<HoldSignal> requiredSignals,
    required Map<HoldSignal, Set<AnalysisSignalRole>> signalRoles,
    Iterable<HoldSignal> supportedSignals = const <HoldSignal>[],
    this.hollowHoldVariation,
  }) : requiredSignals = Set<HoldSignal>.unmodifiable(requiredSignals),
       supportedSignals = Set<HoldSignal>.unmodifiable(<HoldSignal>{
         ...requiredSignals,
         ...supportedSignals,
       }),
       signalRoles = Map<HoldSignal, Set<AnalysisSignalRole>>.unmodifiable(
         <HoldSignal, Set<AnalysisSignalRole>>{
           for (final signal in HoldSignal.values)
             if (signalRoles.containsKey(signal))
               signal: Set<AnalysisSignalRole>.unmodifiable(
                 AnalysisSignalRole.values.where(signalRoles[signal]!.contains),
               ),
         },
       ) {
    if (family == HoldAnalysisFamily.hollowHold &&
        hollowHoldVariation == null) {
      throw ArgumentError(
        'Hollow Hold contracts require an explicit variation contract.',
      );
    }
    if (family != HoldAnalysisFamily.hollowHold &&
        hollowHoldVariation != null) {
      throw ArgumentError(
        'Only Hollow Hold contracts may define a hollowHoldVariation.',
      );
    }

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
  final HollowHoldVariationContract? hollowHoldVariation;

  final Set<HoldSignal> requiredSignals;
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
      // Legacy angular gates remain detection/hold-validation inputs.
      // Core v2 plank technique is owned by derived physical measurements,
      // so these signals no longer masquerade as technique observations.
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
      },
    },
  );

  static final HoldContract hollowHold = hollowHoldForVariation(
    HollowHoldVariation.straightLegOverhead,
  );

  static HoldContract hollowHoldForVariation(HollowHoldVariation variation) {
    final variationContract = HollowHoldVariationContracts.forVariation(
      variation,
    );
    final requiredSignals = <HoldSignal>{
      HoldSignal.compression,
      if (variationContract.requiresArmsOverhead) HoldSignal.armExtension,
      if (variationContract.requiresStraightKnees) HoldSignal.kneeExtension,
    };

    return HoldContract(
      family: HoldAnalysisFamily.hollowHold,
      hollowHoldVariation: variationContract,
      requiredSignals: requiredSignals,
      signalRoles: <HoldSignal, Set<AnalysisSignalRole>>{
        HoldSignal.compression: const <AnalysisSignalRole>{
          AnalysisSignalRole.detection,
          AnalysisSignalRole.setup,
        },
        if (variationContract.requiresArmsOverhead)
          HoldSignal.armExtension: const <AnalysisSignalRole>{
            AnalysisSignalRole.setup,
            AnalysisSignalRole.validation,
          },
        if (variationContract.requiresStraightKnees)
          HoldSignal.kneeExtension: const <AnalysisSignalRole>{
            AnalysisSignalRole.setup,
            AnalysisSignalRole.validation,
          },
      },
    );
  }

  static final HoldContract sidePlank = HoldContract(
    family: HoldAnalysisFamily.sidePlank,
    requiredSignals: const <HoldSignal>{
      HoldSignal.alignment,
      HoldSignal.support,
      HoldSignal.extension,
    },
    supportedSignals: const <HoldSignal>{HoldSignal.supportStacking},
    signalRoles: const <HoldSignal, Set<AnalysisSignalRole>>{
      HoldSignal.alignment: <AnalysisSignalRole>{
        AnalysisSignalRole.detection,
        AnalysisSignalRole.validation,
      },
      HoldSignal.support: <AnalysisSignalRole>{
        AnalysisSignalRole.detection,
        AnalysisSignalRole.validation,
      },
      HoldSignal.supportStacking: <AnalysisSignalRole>{
        AnalysisSignalRole.detection,
        AnalysisSignalRole.validation,
      },
      HoldSignal.extension: <AnalysisSignalRole>{
        AnalysisSignalRole.detection,
        AnalysisSignalRole.validation,
      },
    },
  );

  static final HoldContract wallSit = HoldContract(
    family: HoldAnalysisFamily.wallSit,
    requiredSignals: const <HoldSignal>{
      HoldSignal.kneeFlexion,
      HoldSignal.hipFlexion,
      HoldSignal.torsoAlignment,
    },
    signalRoles: const <HoldSignal, Set<AnalysisSignalRole>>{
      HoldSignal.kneeFlexion: <AnalysisSignalRole>{
        AnalysisSignalRole.detection,
        AnalysisSignalRole.validation,
        AnalysisSignalRole.technique,
      },
      HoldSignal.hipFlexion: <AnalysisSignalRole>{
        AnalysisSignalRole.validation,
        AnalysisSignalRole.technique,
      },
      HoldSignal.torsoAlignment: <AnalysisSignalRole>{
        AnalysisSignalRole.validation,
        AnalysisSignalRole.technique,
      },
    },
  );
}
