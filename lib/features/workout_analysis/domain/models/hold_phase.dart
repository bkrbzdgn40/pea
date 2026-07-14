enum HoldPhase { ready, holding, broken }

extension HoldPhaseX on HoldPhase {
  String get code {
    switch (this) {
      case HoldPhase.ready:
        return 'ready';
      case HoldPhase.holding:
        return 'holding';
      case HoldPhase.broken:
        return 'broken';
    }
  }

  String get legacyLabel => code.toUpperCase();
}
