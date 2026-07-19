enum RangeRepTechniqueObservationType { legacyFormThresholdViolation }

enum RangeRepTechniquePhase { live, descending, peak, ascending, completedRep }

enum RangeRepTechniqueSeverity { info, warning, critical }

class RangeRepTechniqueObservation {
  const RangeRepTechniqueObservation({
    required this.type,
    required this.code,
    required this.severity,
    this.phase,
  });

  final RangeRepTechniqueObservationType type;
  final String code;
  final RangeRepTechniqueSeverity severity;
  final RangeRepTechniquePhase? phase;
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
