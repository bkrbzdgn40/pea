import '../../../workout_analysis/domain/models/exercise_type.dart';
import 'challenge_evidence_quality.dart';
import 'challenge_metric.dart';
import 'challenge_period.dart';
import 'challenge_period_window.dart';

/// Trusted, idempotent quantity emitted by one completed workout session.
class ChallengeContribution {
  ChallengeContribution({
    required this.sessionId,
    required this.challengeId,
    required this.catalogVersion,
    required this.exerciseType,
    required this.metric,
    required this.evidenceQuality,
    required this.value,
    required DateTime endedAt,
    required this.timezoneOffset,
  }) : endedAtUtc = endedAt.toUtc() {
    validateChallengeTimezoneOffset(timezoneOffset);
    if (sessionId.isEmpty || sessionId.contains('/')) {
      throw ArgumentError.value(
        sessionId,
        'sessionId',
        'Must be a non-empty Firestore document id.',
      );
    }
    if (challengeId != '${exerciseType.id}_volume') {
      throw ArgumentError.value(
        challengeId,
        'challengeId',
        'Must identify the exercise volume challenge.',
      );
    }
    if (catalogVersion <= 0) {
      throw ArgumentError.value(
        catalogVersion,
        'catalogVersion',
        'Must be positive.',
      );
    }
    if (!value.isFinite || value <= 0) {
      throw ArgumentError.value(
        value,
        'value',
        'Contribution value must be finite and positive.',
      );
    }
    if (metric == ChallengeMetric.validRepetitions &&
        value != value.roundToDouble()) {
      throw ArgumentError.value(
        value,
        'value',
        'Repetition contributions must be whole numbers.',
      );
    }
  }

  final String sessionId;
  final String challengeId;
  final int catalogVersion;
  final ExerciseType exerciseType;
  final ChallengeMetric metric;
  final ChallengeEvidenceQuality evidenceQuality;
  final double value;
  final DateTime endedAtUtc;
  final Duration timezoneOffset;

  ChallengePeriodWindow get dailyWindow => windowFor(ChallengePeriod.daily);

  ChallengePeriodWindow windowFor(ChallengePeriod period) {
    return ChallengePeriodWindow.forInstant(
      period: period,
      instant: endedAtUtc,
      timezoneOffset: timezoneOffset,
    );
  }

  bool hasSamePayloadAs(ChallengeContribution other) {
    return sessionId == other.sessionId &&
        challengeId == other.challengeId &&
        catalogVersion == other.catalogVersion &&
        exerciseType == other.exerciseType &&
        metric == other.metric &&
        evidenceQuality == other.evidenceQuality &&
        value == other.value &&
        endedAtUtc == other.endedAtUtc &&
        timezoneOffset == other.timezoneOffset;
  }
}
