enum RangeRepTechniqueSeverity { info, warning, critical }

class RangeRepTechniqueObservation {
  const RangeRepTechniqueObservation({
    required this.code,
    required this.severity,
  });

  final String code;
  final RangeRepTechniqueSeverity severity;
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
