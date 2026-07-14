/// Canonical signal identifiers that a hold contract may support.
enum HoldSignal { alignment, support, extension }

/// Immutable contract describing which normalized signals a hold exercise
/// supports.
class HoldContract {
  HoldContract({required Iterable<HoldSignal> requiredSignals})
    : requiredSignals = Set<HoldSignal>.unmodifiable(requiredSignals);

  final Set<HoldSignal> requiredSignals;

  bool supportsSignal(HoldSignal signal) {
    return requiredSignals.contains(signal);
  }
}

/// Predefined hold contracts kept separate from runtime wiring.
abstract final class HoldContracts {
  static final HoldContract plankFamily = HoldContract(
    requiredSignals: const <HoldSignal>{
      HoldSignal.alignment,
      HoldSignal.support,
      HoldSignal.extension,
    },
  );
}
