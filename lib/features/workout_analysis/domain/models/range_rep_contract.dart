import 'analysis_signal_role.dart';

/// Canonical phases for range-rep style movements.
enum RangeRepPhase { descending, peak, ascending }

/// Canonical signal identifiers that a range-rep contract may support.
///
/// These are domain identifiers only. They are not tied to debug telemetry,
/// persistence, UI labels, or a specific exercise implementation.
enum RangeRepSignal {
  primaryMetric,
  formMetric,
  postureAngle,
  depthMetric,
  alignmentMetric,
  stabilityMetric,
  endRangeMetric,
  bottomControlMetric,
}

enum RangeRepSignalSet { supportedAnalysis, poseAcceptanceRequired }

enum RangeRepFormThresholdCalibrationPolicy { enabled, disabled }

enum RangeRepSideMode { selectedSide, bilateral }

/// Declares how the exercise's primary movement signal is measured.
///
/// [jointAngle] preserves the legacy three-landmark angle configured by
/// `joint1 -> primaryJoint -> joint2`.
/// [imagePlaneInclination] measures the `joint1 -> primaryJoint` segment
/// against the image-plane vertical axis using the shared geometry primitive.
enum RangeRepPrimaryMetricKind { jointAngle, imagePlaneInclination }

/// Immutable contract describing which phases and normalized signals a
/// range-rep exercise supports.
class RangeRepContract {
  RangeRepContract({
    required Iterable<RangeRepPhase> supportedPhases,
    required Iterable<RangeRepSignal> supportedSignals,
    required Map<RangeRepSignal, Set<AnalysisSignalRole>> signalRoles,
    Iterable<RangeRepSignal>? poseAcceptanceRequiredSignals,
    this.formThresholdCalibrationPolicy =
        RangeRepFormThresholdCalibrationPolicy.enabled,
    this.sideMode = RangeRepSideMode.selectedSide,
    this.primaryMetricKind = RangeRepPrimaryMetricKind.jointAngle,
  }) : supportedPhases = Set<RangeRepPhase>.unmodifiable(supportedPhases),
       supportedSignals = Set<RangeRepSignal>.unmodifiable(supportedSignals),
       signalRoles = Map<RangeRepSignal, Set<AnalysisSignalRole>>.unmodifiable(
         <RangeRepSignal, Set<AnalysisSignalRole>>{
           for (final signal in RangeRepSignal.values)
             if (signalRoles.containsKey(signal))
               signal: Set<AnalysisSignalRole>.unmodifiable(
                 AnalysisSignalRole.values.where(signalRoles[signal]!.contains),
               ),
         },
       ),
       poseAcceptanceRequiredSignals = Set<RangeRepSignal>.unmodifiable(
         poseAcceptanceRequiredSignals ?? supportedSignals,
       ) {
    final unsupportedPoseAcceptanceSignals = this.poseAcceptanceRequiredSignals
        .difference(this.supportedSignals);
    if (unsupportedPoseAcceptanceSignals.isNotEmpty) {
      throw ArgumentError.value(
        unsupportedPoseAcceptanceSignals,
        'poseAcceptanceRequiredSignals',
        'Pose-acceptance signals must be a subset of supportedSignals.',
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

  final Set<RangeRepPhase> supportedPhases;
  final Set<RangeRepSignal> supportedSignals;
  final Map<RangeRepSignal, Set<AnalysisSignalRole>> signalRoles;
  final Set<RangeRepSignal> poseAcceptanceRequiredSignals;
  final RangeRepFormThresholdCalibrationPolicy formThresholdCalibrationPolicy;
  final RangeRepSideMode sideMode;
  final RangeRepPrimaryMetricKind primaryMetricKind;

  bool supportsPhase(RangeRepPhase phase) {
    return supportedPhases.contains(phase);
  }

  bool supportsSignal(RangeRepSignal signal) {
    return supportedSignals.contains(signal);
  }

  bool requiresPoseAcceptanceSignal(RangeRepSignal signal) {
    return poseAcceptanceRequiredSignals.contains(signal);
  }

  Set<AnalysisSignalRole> rolesForSignal(RangeRepSignal signal) {
    return signalRoles[signal] ?? const <AnalysisSignalRole>{};
  }

  bool signalHasRole(RangeRepSignal signal, AnalysisSignalRole role) {
    return rolesForSignal(signal).contains(role);
  }

  Set<RangeRepSignal> signalsForRole(AnalysisSignalRole role) {
    return Set<RangeRepSignal>.unmodifiable(
      RangeRepSignal.values.where((signal) => signalHasRole(signal, role)),
    );
  }

  Set<RangeRepSignal> signalsFor(RangeRepSignalSet signalSet) {
    switch (signalSet) {
      case RangeRepSignalSet.supportedAnalysis:
        return supportedSignals;
      case RangeRepSignalSet.poseAcceptanceRequired:
        return poseAcceptanceRequiredSignals;
    }
  }
}

/// Predefined range-rep contracts kept separate from runtime wiring.
abstract final class RangeRepContracts {
  static final RangeRepContract squat = RangeRepContract(
    supportedPhases: const <RangeRepPhase>{
      RangeRepPhase.descending,
      RangeRepPhase.peak,
      RangeRepPhase.ascending,
    },
    supportedSignals: const <RangeRepSignal>{
      RangeRepSignal.primaryMetric,
      RangeRepSignal.formMetric,
      RangeRepSignal.postureAngle,
      RangeRepSignal.depthMetric,
      RangeRepSignal.alignmentMetric,
      RangeRepSignal.endRangeMetric,
    },
    signalRoles: const <RangeRepSignal, Set<AnalysisSignalRole>>{
      RangeRepSignal.primaryMetric: <AnalysisSignalRole>{
        AnalysisSignalRole.detection,
        AnalysisSignalRole.validation,
        AnalysisSignalRole.scoring,
      },
      RangeRepSignal.formMetric: <AnalysisSignalRole>{
        AnalysisSignalRole.validation,
        AnalysisSignalRole.technique,
        AnalysisSignalRole.scoring,
      },
      RangeRepSignal.postureAngle: <AnalysisSignalRole>{
        AnalysisSignalRole.technique,
      },
      RangeRepSignal.depthMetric: <AnalysisSignalRole>{
        AnalysisSignalRole.scoring,
      },
      RangeRepSignal.alignmentMetric: <AnalysisSignalRole>{
        AnalysisSignalRole.technique,
      },
      RangeRepSignal.endRangeMetric: <AnalysisSignalRole>{
        AnalysisSignalRole.technique,
      },
    },
  );

  static final RangeRepContract pushUp = RangeRepContract(
    supportedPhases: const <RangeRepPhase>{
      RangeRepPhase.descending,
      RangeRepPhase.peak,
      RangeRepPhase.ascending,
    },
    supportedSignals: const <RangeRepSignal>{
      RangeRepSignal.primaryMetric,
      RangeRepSignal.formMetric,
      RangeRepSignal.postureAngle,
      RangeRepSignal.depthMetric,
      RangeRepSignal.alignmentMetric,
      RangeRepSignal.endRangeMetric,
    },
    signalRoles: const <RangeRepSignal, Set<AnalysisSignalRole>>{
      RangeRepSignal.primaryMetric: <AnalysisSignalRole>{
        AnalysisSignalRole.detection,
        AnalysisSignalRole.validation,
        AnalysisSignalRole.scoring,
      },
      RangeRepSignal.formMetric: <AnalysisSignalRole>{
        AnalysisSignalRole.validation,
        AnalysisSignalRole.technique,
        AnalysisSignalRole.scoring,
      },
      RangeRepSignal.postureAngle: <AnalysisSignalRole>{
        AnalysisSignalRole.technique,
      },
      RangeRepSignal.depthMetric: <AnalysisSignalRole>{
        AnalysisSignalRole.scoring,
      },
      RangeRepSignal.alignmentMetric: <AnalysisSignalRole>{
        AnalysisSignalRole.technique,
      },
      RangeRepSignal.endRangeMetric: <AnalysisSignalRole>{
        AnalysisSignalRole.technique,
      },
    },
  );

  static final RangeRepContract sitUp = RangeRepContract(
    supportedPhases: const <RangeRepPhase>{
      RangeRepPhase.descending,
      RangeRepPhase.peak,
      RangeRepPhase.ascending,
    },
    supportedSignals: const <RangeRepSignal>{
      RangeRepSignal.primaryMetric,
      RangeRepSignal.formMetric,
      RangeRepSignal.postureAngle,
      RangeRepSignal.depthMetric,
    },
    signalRoles: const <RangeRepSignal, Set<AnalysisSignalRole>>{
      RangeRepSignal.primaryMetric: <AnalysisSignalRole>{
        AnalysisSignalRole.detection,
        AnalysisSignalRole.validation,
        AnalysisSignalRole.scoring,
      },
      RangeRepSignal.formMetric: <AnalysisSignalRole>{AnalysisSignalRole.setup},
      RangeRepSignal.postureAngle: <AnalysisSignalRole>{
        AnalysisSignalRole.setup,
      },
      RangeRepSignal.depthMetric: <AnalysisSignalRole>{
        AnalysisSignalRole.scoring,
      },
    },
    poseAcceptanceRequiredSignals: const <RangeRepSignal>{
      RangeRepSignal.primaryMetric,
    },
    formThresholdCalibrationPolicy:
        RangeRepFormThresholdCalibrationPolicy.disabled,
    primaryMetricKind: RangeRepPrimaryMetricKind.imagePlaneInclination,
  );

  static final RangeRepContract bicepsCurl = RangeRepContract(
    supportedPhases: const <RangeRepPhase>{
      RangeRepPhase.descending,
      RangeRepPhase.peak,
      RangeRepPhase.ascending,
    },
    supportedSignals: const <RangeRepSignal>{
      RangeRepSignal.primaryMetric,
      RangeRepSignal.formMetric,
      RangeRepSignal.postureAngle,
      RangeRepSignal.depthMetric,
    },
    signalRoles: const <RangeRepSignal, Set<AnalysisSignalRole>>{
      RangeRepSignal.primaryMetric: <AnalysisSignalRole>{
        AnalysisSignalRole.detection,
        AnalysisSignalRole.validation,
        AnalysisSignalRole.scoring,
      },
      RangeRepSignal.formMetric: <AnalysisSignalRole>{
        AnalysisSignalRole.validation,
        AnalysisSignalRole.technique,
        AnalysisSignalRole.scoring,
      },
      RangeRepSignal.postureAngle: <AnalysisSignalRole>{
        AnalysisSignalRole.technique,
      },
      RangeRepSignal.depthMetric: <AnalysisSignalRole>{
        AnalysisSignalRole.scoring,
      },
    },
    poseAcceptanceRequiredSignals: const <RangeRepSignal>{
      RangeRepSignal.primaryMetric,
      RangeRepSignal.formMetric,
    },
    formThresholdCalibrationPolicy:
        RangeRepFormThresholdCalibrationPolicy.disabled,
    sideMode: RangeRepSideMode.bilateral,
  );
}
