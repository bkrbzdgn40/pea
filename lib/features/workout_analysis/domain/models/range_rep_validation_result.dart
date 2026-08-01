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
  excessiveRepSpeed,
  persistentFormBreak,
  coverageLoss,
  sideSwitchDuringRep,
  incompletePhase,
}

extension RangeRepValidationReasonX on RangeRepValidationReason {
  bool get isTempoMeasurementReason {
    return switch (this) {
      RangeRepValidationReason.excessiveDescentSpeed ||
      RangeRepValidationReason.excessiveAscentSpeed ||
      RangeRepValidationReason.excessiveRepSpeed => true,
      _ => false,
    };
  }

  bool get isMeasurementQualityReason {
    return switch (this) {
      RangeRepValidationReason.coverageLoss ||
      RangeRepValidationReason.sideSwitchDuringRep => true,
      _ => false,
    };
  }

  bool get isTechniqueOutcomeReason {
    return switch (this) {
      RangeRepValidationReason.insufficientRom ||
      RangeRepValidationReason.persistentFormBreak ||
      RangeRepValidationReason.incompletePhase => true,
      _ => false,
    };
  }

  bool get excludesTempoFromMainScore =>
      isTempoMeasurementReason || isMeasurementQualityReason;

  String get debugLabel {
    switch (this) {
      case RangeRepValidationReason.insufficientRom:
        return 'insufficient rom';
      case RangeRepValidationReason.excessiveDescentSpeed:
        return 'excessive descent speed';
      case RangeRepValidationReason.excessiveAscentSpeed:
        return 'excessive ascent speed';
      case RangeRepValidationReason.excessiveRepSpeed:
        return 'excessive rep speed';
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
    required List<RangeRepValidationReason> tempoDiagnosticReasons,
  }) : reasons = List.unmodifiable(reasons),
       tempoDiagnosticReasons = List.unmodifiable(tempoDiagnosticReasons);

  factory RangeRepValidationResult.valid({
    List<RangeRepValidationReason> tempoDiagnosticReasons =
        const <RangeRepValidationReason>[],
  }) {
    return RangeRepValidationResult._(
      status: RangeRepValidationStatus.valid,
      reasons: const <RangeRepValidationReason>[],
      tempoDiagnosticReasons: tempoDiagnosticReasons,
    );
  }

  factory RangeRepValidationResult.lowConfidence(
    List<RangeRepValidationReason> reasons, {
    List<RangeRepValidationReason> tempoDiagnosticReasons =
        const <RangeRepValidationReason>[],
  }) {
    return RangeRepValidationResult._(
      status: RangeRepValidationStatus.lowConfidence,
      reasons: reasons,
      tempoDiagnosticReasons: tempoDiagnosticReasons,
    );
  }

  factory RangeRepValidationResult.invalid(
    List<RangeRepValidationReason> reasons, {
    List<RangeRepValidationReason> tempoDiagnosticReasons =
        const <RangeRepValidationReason>[],
  }) {
    return RangeRepValidationResult._(
      status: RangeRepValidationStatus.invalid,
      reasons: reasons,
      tempoDiagnosticReasons: tempoDiagnosticReasons,
    );
  }

  final RangeRepValidationStatus status;

  /// User-facing reasons that may affect validation status, accepted counters,
  /// persistence, and presentation.
  final List<RangeRepValidationReason> reasons;

  /// Raw tempo threshold findings retained for developer diagnostics while the
  /// timing pipeline is quarantined. These findings must not be interpreted as
  /// user validation reasons until Tempo Measurement V2 enables them.
  final List<RangeRepValidationReason> tempoDiagnosticReasons;

  bool get isValid => status == RangeRepValidationStatus.valid;

  /// A valid or cautionary completed movement counts as a user repetition.
  /// Invalid attempts remain visible as corrective outcomes but do not advance
  /// the live repetition total or publish a score.
  bool get countsTowardReps => status != RangeRepValidationStatus.invalid;

  bool get shouldPublishScore => countsTowardReps;

  /// Whether the validation outcome permits an independently eligible tempo
  /// measurement to contribute to the score. Measurement eligibility is owned
  /// by Tempo Measurement V2 and must still be checked separately.
  bool get allowsTempoInMainScore =>
      !reasons.any((reason) => reason.excludesTempoFromMainScore);

  @Deprecated('Use allowsTempoInMainScore with TempoMeasurementAssessment.')
  bool get shouldIncludeTempoInMainScore => allowsTempoInMainScore;
}
