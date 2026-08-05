import 'models/session_measurement_evidence.dart';
import 'models/workout_rep.dart';

/// Builds session-level measurement evidence from persisted rep facts.
class SessionMeasurementEvidencePolicy {
  const SessionMeasurementEvidencePolicy();

  static const int minimumReliableSampleCount = 2;
  static const double highConfidenceThreshold = 0.90;
  static const double moderateConfidenceThreshold = 0.80;
  static const double maximumModerateLowConfidenceRatio = 0.25;

  SessionMeasurementEvidence evaluate({
    required PreparationOutcome preparationOutcome,
    required Iterable<WorkoutRep> reps,
  }) {
    final repList = reps.toList(growable: false);
    final knownConfidenceValues = repList
        .map((rep) => rep.effectiveMeasurementConfidence?.combined)
        .whereType<double>()
        .where((value) => value.isFinite)
        .toList(growable: false);

    if (knownConfidenceValues.isEmpty) {
      return SessionMeasurementEvidence.unknown(
        preparationOutcome: preparationOutcome,
      );
    }

    final confidenceTotal = knownConfidenceValues.fold<double>(
      0,
      (sum, value) => sum + value,
    );
    final averageConfidence = confidenceTotal / knownConfidenceValues.length;
    final acceptedReps = repList.where(
      (rep) => rep.isValidatedAsValid || rep.isValidatedAsLowConfidence,
    );
    final acceptedCount = acceptedReps.length;
    final lowConfidenceCount = acceptedReps
        .where((rep) => rep.isValidatedAsLowConfidence)
        .length;
    final lowConfidenceRatio = acceptedCount == 0
        ? 1.0
        : lowConfidenceCount / acceptedCount;

    return SessionMeasurementEvidence(
      preparationOutcome: preparationOutcome,
      measurementQuality: _classify(
        preparationOutcome: preparationOutcome,
        averageConfidence: averageConfidence,
        sampleCount: knownConfidenceValues.length,
        lowConfidenceRatio: lowConfidenceRatio,
      ),
      averageMeasurementConfidence: averageConfidence,
      measurementSampleCount: knownConfidenceValues.length,
    );
  }

  SessionMeasurementQuality _classify({
    required PreparationOutcome preparationOutcome,
    required double averageConfidence,
    required int sampleCount,
    required double lowConfidenceRatio,
  }) {
    if (sampleCount < minimumReliableSampleCount) {
      return SessionMeasurementQuality.insufficient;
    }

    if (preparationOutcome != PreparationOutcome.passed) {
      return SessionMeasurementQuality.limited;
    }

    if (averageConfidence >= highConfidenceThreshold &&
        lowConfidenceRatio == 0) {
      return SessionMeasurementQuality.high;
    }

    if (averageConfidence >= moderateConfidenceThreshold &&
        lowConfidenceRatio <= maximumModerateLowConfidenceRatio) {
      return SessionMeasurementQuality.moderate;
    }

    return SessionMeasurementQuality.limited;
  }
}
