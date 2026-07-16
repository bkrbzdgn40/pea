enum HoldAnalysisFamily { plank }

/// Canonical signal identifiers that a hold contract may support.
enum HoldSignal { alignment, support, extension }

/// Immutable contract describing which normalized signals a hold exercise
/// supports.
class HoldContract {
  HoldContract({
    required this.family,
    required Iterable<HoldSignal> requiredSignals,
  }) : requiredSignals = Set<HoldSignal>.unmodifiable(requiredSignals);

  final HoldAnalysisFamily family;

  final Set<HoldSignal> requiredSignals;

  bool supportsSignal(HoldSignal signal) {
    return requiredSignals.contains(signal);
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
  );
}
