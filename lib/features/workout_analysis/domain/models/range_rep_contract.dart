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

/// Immutable contract describing which phases and normalized signals a
/// range-rep exercise supports.
class RangeRepContract {
  RangeRepContract({
    required Iterable<RangeRepPhase> supportedPhases,
    required Iterable<RangeRepSignal> supportedSignals,
    Iterable<RangeRepSignal>? poseAcceptanceRequiredSignals,
    this.formThresholdCalibrationPolicy =
        RangeRepFormThresholdCalibrationPolicy.enabled,
    this.sideMode = RangeRepSideMode.selectedSide,
  }) : supportedPhases = Set<RangeRepPhase>.unmodifiable(supportedPhases),
       supportedSignals = Set<RangeRepSignal>.unmodifiable(supportedSignals),
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
  }

  final Set<RangeRepPhase> supportedPhases;
  final Set<RangeRepSignal> supportedSignals;
  final Set<RangeRepSignal> poseAcceptanceRequiredSignals;
  final RangeRepFormThresholdCalibrationPolicy formThresholdCalibrationPolicy;
  final RangeRepSideMode sideMode;

  bool supportsPhase(RangeRepPhase phase) {
    return supportedPhases.contains(phase);
  }

  bool supportsSignal(RangeRepSignal signal) {
    return supportedSignals.contains(signal);
  }

  bool requiresPoseAcceptanceSignal(RangeRepSignal signal) {
    return poseAcceptanceRequiredSignals.contains(signal);
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
    poseAcceptanceRequiredSignals: const <RangeRepSignal>{
      RangeRepSignal.primaryMetric,
    },
    formThresholdCalibrationPolicy:
        RangeRepFormThresholdCalibrationPolicy.disabled,
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
    poseAcceptanceRequiredSignals: const <RangeRepSignal>{
      RangeRepSignal.primaryMetric,
      RangeRepSignal.formMetric,
    },
    formThresholdCalibrationPolicy:
        RangeRepFormThresholdCalibrationPolicy.disabled,
    sideMode: RangeRepSideMode.bilateral,
  );
}
