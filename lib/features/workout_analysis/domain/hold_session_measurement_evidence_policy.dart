import 'models/session_measurement_evidence.dart';

/// Builds session-level measurement evidence for hold-style exercises.
///
/// Hold technique correctness is deliberately excluded. This policy answers
/// only whether the camera evidence was stable and complete enough to trust
/// the persisted hold duration.
class HoldSessionMeasurementEvidencePolicy {
  const HoldSessionMeasurementEvidencePolicy();

  static const double minimumReliableHoldSeconds = 5.0;
  static const int minimumReliableSampleCount = 5;
  static const double highConfidenceThreshold = 0.90;
  static const double moderateConfidenceThreshold = 0.80;
  static const double maximumHighVisibilityInterruptionRatio = 0.0;
  static const double maximumModerateVisibilityInterruptionRatio = 0.20;

  SessionMeasurementEvidence evaluate({
    required PreparationOutcome preparationOutcome,
    required double totalHoldSeconds,
    required double? averageMeasurementConfidence,
    required int measurementSampleCount,
    required int observedHoldFrameCount,
    required int visibilityInterruptedFrameCount,
  }) {
    if (!totalHoldSeconds.isFinite || totalHoldSeconds < 0) {
      throw ArgumentError.value(
        totalHoldSeconds,
        'totalHoldSeconds',
        'must be finite and non-negative',
      );
    }
    if (measurementSampleCount < 0) {
      throw ArgumentError.value(
        measurementSampleCount,
        'measurementSampleCount',
        'must be non-negative',
      );
    }
    if (observedHoldFrameCount < 0) {
      throw ArgumentError.value(
        observedHoldFrameCount,
        'observedHoldFrameCount',
        'must be non-negative',
      );
    }
    if (measurementSampleCount > observedHoldFrameCount) {
      throw ArgumentError.value(
        measurementSampleCount,
        'measurementSampleCount',
        'must not exceed observedHoldFrameCount',
      );
    }
    if (visibilityInterruptedFrameCount < 0 ||
        visibilityInterruptedFrameCount > observedHoldFrameCount) {
      throw ArgumentError.value(
        visibilityInterruptedFrameCount,
        'visibilityInterruptedFrameCount',
        'must be between zero and observedHoldFrameCount',
      );
    }
    if (averageMeasurementConfidence != null &&
        (!averageMeasurementConfidence.isFinite ||
            averageMeasurementConfidence < 0 ||
            averageMeasurementConfidence > 1)) {
      throw ArgumentError.value(
        averageMeasurementConfidence,
        'averageMeasurementConfidence',
        'must be finite and between zero and one',
      );
    }
    if ((averageMeasurementConfidence == null) !=
        (measurementSampleCount == 0)) {
      throw ArgumentError(
        'averageMeasurementConfidence and measurementSampleCount disagree.',
      );
    }

    if (measurementSampleCount == 0) {
      return SessionMeasurementEvidence.unknown(
        preparationOutcome: preparationOutcome,
      );
    }

    if (measurementSampleCount == 1) {
      return SessionMeasurementEvidence(
        preparationOutcome: preparationOutcome,
        measurementQuality: SessionMeasurementQuality.insufficient,
        averageMeasurementConfidence: averageMeasurementConfidence,
        measurementSampleCount: measurementSampleCount,
      );
    }

    final visibilityInterruptionRatio = observedHoldFrameCount == 0
        ? 1.0
        : visibilityInterruptedFrameCount / observedHoldFrameCount;
    final quality = _classify(
      preparationOutcome: preparationOutcome,
      totalHoldSeconds: totalHoldSeconds,
      averageMeasurementConfidence: averageMeasurementConfidence!,
      measurementSampleCount: measurementSampleCount,
      visibilityInterruptionRatio: visibilityInterruptionRatio,
    );

    return SessionMeasurementEvidence(
      preparationOutcome: preparationOutcome,
      measurementQuality: quality,
      averageMeasurementConfidence: averageMeasurementConfidence,
      measurementSampleCount: measurementSampleCount,
    );
  }

  SessionMeasurementQuality _classify({
    required PreparationOutcome preparationOutcome,
    required double totalHoldSeconds,
    required double averageMeasurementConfidence,
    required int measurementSampleCount,
    required double visibilityInterruptionRatio,
  }) {
    if (preparationOutcome != PreparationOutcome.passed ||
        totalHoldSeconds < minimumReliableHoldSeconds ||
        measurementSampleCount < minimumReliableSampleCount) {
      return SessionMeasurementQuality.limited;
    }

    if (averageMeasurementConfidence >= highConfidenceThreshold &&
        visibilityInterruptionRatio <= maximumHighVisibilityInterruptionRatio) {
      return SessionMeasurementQuality.high;
    }

    if (averageMeasurementConfidence >= moderateConfidenceThreshold &&
        visibilityInterruptionRatio <=
            maximumModerateVisibilityInterruptionRatio) {
      return SessionMeasurementQuality.moderate;
    }

    return SessionMeasurementQuality.limited;
  }
}
