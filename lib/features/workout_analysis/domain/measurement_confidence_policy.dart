import 'models/measurement_confidence_breakdown.dart';

/// Produces the single combined Measurement Confidence V2 value.
///
/// The policy combines measurement dimensions only. Technique outcome, range
/// of motion, repetition validity, and tempo execution are intentionally not
/// inputs to this calculation.
class MeasurementConfidencePolicy {
  const MeasurementConfidencePolicy();

  static const double landmarkLikelihoodWeight = 0.40;
  static const double signalAvailabilityWeight = 0.25;
  static const double geometryPlausibilityWeight = 0.20;
  static const double temporalContinuityWeight = 0.15;

  MeasurementConfidenceBreakdown evaluate({
    required double? landmarkLikelihood,
    required double? signalAvailability,
    required double? geometryPlausibility,
    required double? temporalContinuity,
    List<MeasurementConfidenceIssue> issues =
        const <MeasurementConfidenceIssue>[],
  }) {
    final validatedInput = MeasurementConfidenceBreakdown(
      landmarkLikelihood: landmarkLikelihood,
      signalAvailability: signalAvailability,
      geometryPlausibility: geometryPlausibility,
      temporalContinuity: temporalContinuity,
      combined: null,
      issues: issues,
    );

    final combined = _weightedHarmonicMean(
      landmarkLikelihood: validatedInput.landmarkLikelihood,
      signalAvailability: validatedInput.signalAvailability,
      geometryPlausibility: validatedInput.geometryPlausibility,
      temporalContinuity: validatedInput.temporalContinuity,
    );

    return MeasurementConfidenceBreakdown(
      landmarkLikelihood: validatedInput.landmarkLikelihood,
      signalAvailability: validatedInput.signalAvailability,
      geometryPlausibility: validatedInput.geometryPlausibility,
      temporalContinuity: validatedInput.temporalContinuity,
      combined: combined,
      issues: validatedInput.issues,
    );
  }

  double? _weightedHarmonicMean({
    required double? landmarkLikelihood,
    required double? signalAvailability,
    required double? geometryPlausibility,
    required double? temporalContinuity,
  }) {
    if (landmarkLikelihood == null ||
        signalAvailability == null ||
        geometryPlausibility == null ||
        temporalContinuity == null) {
      return null;
    }

    if (landmarkLikelihood == 0.0 ||
        signalAvailability == 0.0 ||
        geometryPlausibility == 0.0 ||
        temporalContinuity == 0.0) {
      return 0.0;
    }

    const totalWeight =
        landmarkLikelihoodWeight +
        signalAvailabilityWeight +
        geometryPlausibilityWeight +
        temporalContinuityWeight;
    final weightedReciprocalSum =
        (landmarkLikelihoodWeight / landmarkLikelihood) +
        (signalAvailabilityWeight / signalAvailability) +
        (geometryPlausibilityWeight / geometryPlausibility) +
        (temporalContinuityWeight / temporalContinuity);

    return (totalWeight / weightedReciprocalSum).clamp(0.0, 1.0).toDouble();
  }
}
