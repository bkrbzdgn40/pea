enum RangeRepTechniqueObservationType {
  legacyFormThresholdViolation,
  torsoDrift,
}

enum RangeRepTechniquePhase { live, descending, peak, ascending, completedRep }

enum RangeRepTechniqueSeverity { info, warning, critical }

class RangeRepTechniqueObservation {
  const RangeRepTechniqueObservation({
    required this.type,
    required this.code,
    required this.severity,
    this.phase,
    this.referencePhase,
    this.measuredValue,
    this.referenceValue,
  });

  final RangeRepTechniqueObservationType type;
  final String code;
  final RangeRepTechniqueSeverity severity;
  final RangeRepTechniquePhase? phase;
  final RangeRepTechniquePhase? referencePhase;
  final double? measuredValue;
  final double? referenceValue;

  double? get deltaValue {
    final measuredValue = this.measuredValue;
    final referenceValue = this.referenceValue;
    if (measuredValue == null || referenceValue == null) {
      return null;
    }
    return measuredValue - referenceValue;
  }
}

class RangeRepTechniqueAssessment {
  RangeRepTechniqueAssessment({
    required List<RangeRepTechniqueObservation> observations,
  }) : observations = List.unmodifiable(observations);

  const RangeRepTechniqueAssessment._({required this.observations});

  static const empty = RangeRepTechniqueAssessment._(
    observations: <RangeRepTechniqueObservation>[],
  );

  final List<RangeRepTechniqueObservation> observations;

  bool get hasObservations => observations.isNotEmpty;
}
