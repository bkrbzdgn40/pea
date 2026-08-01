import 'tempo_measurement_assessment.dart';

/// User-facing tempo classification for one completed repetition.
enum RepTempoQuality { unavailable, target, tooFast, tooSlow }

/// Severity within a fast or slow tempo classification.
enum RepTempoSeverity { none, mild, strong }

/// Machine-readable coaching reasons for one repetition.
enum RepTempoReason {
  coachingDisabled,
  measurementUnavailable,
  eccentricTooFast,
  concentricTooFast,
  totalTooFast,
  eccentricTooSlow,
  concentricTooSlow,
  totalTooSlow,
}

/// Separates timing integrity from execution-quality coaching.
///
/// [measurement] answers whether tempo can be trusted. [quality] answers what
/// that trusted measurement means for the current exercise. Tempo quality never
/// changes repetition validity or accepted repetition counts.
class RepTempoAssessment {
  RepTempoAssessment({
    required this.quality,
    required this.severity,
    required List<RepTempoReason> reasons,
    required this.measurement,
    required this.coachingEnabled,
  }) : reasons = List<RepTempoReason>.unmodifiable(reasons);

  factory RepTempoAssessment.unavailable({
    required TempoMeasurementAssessment measurement,
    required RepTempoReason reason,
    required bool coachingEnabled,
  }) {
    return RepTempoAssessment(
      quality: RepTempoQuality.unavailable,
      severity: RepTempoSeverity.none,
      reasons: <RepTempoReason>[reason],
      measurement: measurement,
      coachingEnabled: coachingEnabled,
    );
  }

  final RepTempoQuality quality;
  final RepTempoSeverity severity;
  final List<RepTempoReason> reasons;
  final TempoMeasurementAssessment measurement;
  final bool coachingEnabled;

  bool get isMeasurementEligible => measurement.isEligible;

  bool get isAvailable => quality != RepTempoQuality.unavailable;

  bool get shouldIncludeInScore => coachingEnabled && isAvailable;

  Map<String, Object?> toJson() => <String, Object?>{
    'quality': quality.name,
    'severity': severity.name,
    'reasons': reasons.map((reason) => reason.name).toList(growable: false),
    'coaching_enabled': coachingEnabled,
    'measurement': measurement.toJson(),
  };
}
