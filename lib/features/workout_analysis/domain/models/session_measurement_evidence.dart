/// How the preparation gate approved entry into live analysis.
enum PreparationOutcome {
  passed,
  overridden,
  legacyUnknown;

  static PreparationOutcome fromWireValue(Object? value) {
    return switch (value) {
      'passed' => PreparationOutcome.passed,
      'overridden' => PreparationOutcome.overridden,
      _ => PreparationOutcome.legacyUnknown,
    };
  }
}

/// Session-level summary of how much trust can be placed in camera evidence.
///
/// This describes measurement evidence only. It is not a technique, safety,
/// or clinical outcome.
enum SessionMeasurementQuality {
  high,
  moderate,
  limited,
  insufficient,
  unknown;

  static SessionMeasurementQuality fromWireValue(Object? value) {
    return switch (value) {
      'high' => SessionMeasurementQuality.high,
      'moderate' => SessionMeasurementQuality.moderate,
      'limited' => SessionMeasurementQuality.limited,
      'insufficient' => SessionMeasurementQuality.insufficient,
      _ => SessionMeasurementQuality.unknown,
    };
  }
}

/// Immutable evidence summary persisted with a completed workout session.
class SessionMeasurementEvidence {
  const SessionMeasurementEvidence({
    required this.preparationOutcome,
    required this.measurementQuality,
    required this.averageMeasurementConfidence,
    required this.measurementSampleCount,
  }) : assert(measurementSampleCount >= 0),
       assert(
         averageMeasurementConfidence == null ||
             (averageMeasurementConfidence >= 0 &&
                 averageMeasurementConfidence <= 1),
       ),
       assert(
         (averageMeasurementConfidence == null &&
                 measurementSampleCount == 0) ||
             (averageMeasurementConfidence != null &&
                 measurementSampleCount > 0),
       ),
       assert(
         (measurementSampleCount == 0 &&
                 measurementQuality == SessionMeasurementQuality.unknown) ||
             (measurementSampleCount == 1 &&
                 measurementQuality ==
                     SessionMeasurementQuality.insufficient) ||
             (measurementSampleCount >= 2 &&
                 measurementQuality != SessionMeasurementQuality.unknown &&
                 measurementQuality != SessionMeasurementQuality.insufficient),
       ),
       assert(
         preparationOutcome == PreparationOutcome.passed ||
             (measurementQuality != SessionMeasurementQuality.high &&
                 measurementQuality != SessionMeasurementQuality.moderate),
       );

  factory SessionMeasurementEvidence.unknown({
    PreparationOutcome preparationOutcome = PreparationOutcome.legacyUnknown,
  }) {
    return SessionMeasurementEvidence(
      preparationOutcome: preparationOutcome,
      measurementQuality: SessionMeasurementQuality.unknown,
      averageMeasurementConfidence: null,
      measurementSampleCount: 0,
    );
  }

  final PreparationOutcome preparationOutcome;
  final SessionMeasurementQuality measurementQuality;
  final double? averageMeasurementConfidence;
  final int measurementSampleCount;
}
