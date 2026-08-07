import 'models/session_measurement_evidence.dart';
import 'models/workout_session.dart';

/// Central policy for deciding how persisted camera evidence may contribute to
/// progress surfaces.
///
/// Completed sessions are never hidden. This policy only controls whether a
/// score or repetition count is reliable enough for comparisons, aggregates,
/// goals, and achievements.
class SessionEvidenceEligibilityPolicy {
  const SessionEvidenceEligibilityPolicy();

  bool countsAsCompletedSession(WorkoutSession session) => true;

  bool appearsInScoreTrend(WorkoutSession session) {
    if (!_hasRangeRepScore(session)) {
      return false;
    }

    return switch (session.measurementQuality) {
      SessionMeasurementQuality.high ||
      SessionMeasurementQuality.moderate ||
      SessionMeasurementQuality.limited => true,
      SessionMeasurementQuality.insufficient => false,
      SessionMeasurementQuality.unknown =>
        session.preparationOutcome == PreparationOutcome.legacyUnknown,
    };
  }

  bool contributesToScoreAggregates(WorkoutSession session) {
    if (!_hasRangeRepScore(session)) {
      return false;
    }

    return _hasTrustedOrLegacyEvidence(session);
  }

  bool contributesToRepetitionVolume(WorkoutSession session) {
    if (session.totalReps <= 0) {
      return false;
    }

    return _hasTrustedOrLegacyEvidence(session);
  }

  bool _hasRangeRepScore(WorkoutSession session) {
    return session.analysisKind == 'rangeRep' && session.averageScore > 0;
  }

  bool _hasTrustedOrLegacyEvidence(WorkoutSession session) {
    return switch (session.measurementQuality) {
      SessionMeasurementQuality.high ||
      SessionMeasurementQuality.moderate => true,
      SessionMeasurementQuality.limited ||
      SessionMeasurementQuality.insufficient => false,
      SessionMeasurementQuality.unknown =>
        session.preparationOutcome == PreparationOutcome.legacyUnknown,
    };
  }
}
