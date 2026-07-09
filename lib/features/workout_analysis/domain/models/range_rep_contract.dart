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

/// Immutable contract describing which phases and normalized signals a
/// range-rep exercise supports.
class RangeRepContract {
  RangeRepContract({
    required Iterable<RangeRepPhase> supportedPhases,
    required Iterable<RangeRepSignal> supportedSignals,
  }) : supportedPhases = Set<RangeRepPhase>.unmodifiable(supportedPhases),
       supportedSignals = Set<RangeRepSignal>.unmodifiable(supportedSignals);

  final Set<RangeRepPhase> supportedPhases;
  final Set<RangeRepSignal> supportedSignals;

  bool supportsPhase(RangeRepPhase phase) {
    return supportedPhases.contains(phase);
  }

  bool supportsSignal(RangeRepSignal signal) {
    return supportedSignals.contains(signal);
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
}
