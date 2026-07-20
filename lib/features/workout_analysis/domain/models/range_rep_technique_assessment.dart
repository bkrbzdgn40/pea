enum RangeRepTechniqueObservationType {
  legacyFormThresholdViolation,
  torsoDrift,
  torsoSwing,
}

enum RangeRepTechniquePhase {
  live,
  neutral,
  descending,
  peak,
  ascending,
  completedRep,
}

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

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'type': type.name,
      'code': code,
      'severity': severity.name,
      'phase': phase?.name,
      'referencePhase': referencePhase?.name,
      'measuredValue': measuredValue,
      'referenceValue': referenceValue,
    };
  }

  factory RangeRepTechniqueObservation.fromMap(Map<String, Object?> map) {
    return RangeRepTechniqueObservation(
      type: RangeRepTechniqueObservationType.values.byName(
        map['type'] as String,
      ),
      code: map['code'] as String,
      severity: RangeRepTechniqueSeverity.values.byName(
        map['severity'] as String,
      ),
      phase: map['phase'] is String
          ? RangeRepTechniquePhase.values.byName(map['phase'] as String)
          : null,
      referencePhase: map['referencePhase'] is String
          ? RangeRepTechniquePhase.values.byName(
              map['referencePhase'] as String,
            )
          : null,
      measuredValue: (map['measuredValue'] as num?)?.toDouble(),
      referenceValue: (map['referenceValue'] as num?)?.toDouble(),
    );
  }

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
