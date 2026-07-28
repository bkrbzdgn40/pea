enum RangeRepValidationStatus { valid, lowConfidence, invalid }

extension RangeRepValidationStatusX on RangeRepValidationStatus {
  String get debugLabel {
    switch (this) {
      case RangeRepValidationStatus.valid:
        return 'valid';
      case RangeRepValidationStatus.lowConfidence:
        return 'low confidence';
      case RangeRepValidationStatus.invalid:
        return 'invalid';
    }
  }
}

enum RangeRepValidationReason {
  insufficientRom,
  excessiveDescentSpeed,
  excessiveAscentSpeed,
  persistentFormBreak,
  coverageLoss,
  sideSwitchDuringRep,
  incompletePhase,
}

extension RangeRepValidationReasonX on RangeRepValidationReason {
  String get debugLabel {
    switch (this) {
      case RangeRepValidationReason.insufficientRom:
        return 'insufficient rom';
      case RangeRepValidationReason.excessiveDescentSpeed:
        return 'excessive descent speed';
      case RangeRepValidationReason.excessiveAscentSpeed:
        return 'excessive ascent speed';
      case RangeRepValidationReason.persistentFormBreak:
        return 'persistent form break';
      case RangeRepValidationReason.coverageLoss:
        return 'coverage loss';
      case RangeRepValidationReason.sideSwitchDuringRep:
        return 'side switch during rep';
      case RangeRepValidationReason.incompletePhase:
        return 'incomplete phase';
    }
  }
}

class RangeRepValidationResult {
  RangeRepValidationResult._({
    required this.status,
    required List<RangeRepValidationReason> reasons,
  }) : reasons = List.unmodifiable(reasons);

  factory RangeRepValidationResult.valid() {
    return RangeRepValidationResult._(
      status: RangeRepValidationStatus.valid,
      reasons: const <RangeRepValidationReason>[],
    );
  }

  factory RangeRepValidationResult.lowConfidence(
    List<RangeRepValidationReason> reasons,
  ) {
    return RangeRepValidationResult._(
      status: RangeRepValidationStatus.lowConfidence,
      reasons: reasons,
    );
  }

  factory RangeRepValidationResult.invalid(
    List<RangeRepValidationReason> reasons,
  ) {
    return RangeRepValidationResult._(
      status: RangeRepValidationStatus.invalid,
      reasons: reasons,
    );
  }

  final RangeRepValidationStatus status;
  final List<RangeRepValidationReason> reasons;

  bool get isValid => status == RangeRepValidationStatus.valid;

  /// A valid or cautionary completed movement counts as a user repetition.
  /// Invalid attempts remain visible as corrective outcomes but do not advance
  /// the live repetition total or publish a score.
  bool get countsTowardReps => status != RangeRepValidationStatus.invalid;

  bool get shouldPublishScore => countsTowardReps;
}
