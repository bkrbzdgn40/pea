/// Technique observations for hold-family exercises.
///
/// These observations are intentionally separate from pose acceptance, hold
/// validity, hold-break decisions, and user feedback. A severity label is an
/// explanation aid, not an implicit runtime gate.
enum HoldTechniqueObservationType {
  plankHipDeviation,
  plankShoulderElbowOffset,
  plankKneeExtension,
}

enum HoldTechniqueSeverity { info, warning, critical }

class HoldTechniqueObservation {
  const HoldTechniqueObservation({
    required this.type,
    required this.code,
    required this.severity,
    this.measuredValue,
    this.referenceValue,
    this.legacyGatePassed,
  });

  final HoldTechniqueObservationType type;
  final String code;
  final HoldTechniqueSeverity severity;
  final double? measuredValue;
  final double? referenceValue;

  /// Compatibility-only signal showing whether the pre-Core-v2 hard gate
  /// passed. This does not make severity itself a hold-validity decision.
  final bool? legacyGatePassed;
}

class HoldTechniqueAssessment {
  HoldTechniqueAssessment({
    required List<HoldTechniqueObservation> observations,
  }) : observations = List<HoldTechniqueObservation>.unmodifiable(observations);

  const HoldTechniqueAssessment._({required this.observations});

  static const empty = HoldTechniqueAssessment._(
    observations: <HoldTechniqueObservation>[],
  );

  final List<HoldTechniqueObservation> observations;

  /// R23 designates normalized plank hip-line deviation as the primary plank
  /// technique measurement. Other observations remain corroborating signals.
  HoldTechniqueObservation? get primaryPlankObservation {
    for (final observation in observations) {
      if (observation.type == HoldTechniqueObservationType.plankHipDeviation) {
        return observation;
      }
    }
    return null;
  }

  bool get hasObservations => observations.isNotEmpty;
}
