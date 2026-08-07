import '../../workout_analysis/domain/models/session_measurement_evidence.dart';
import '../../workout_analysis/domain/models/workout_session.dart';
import 'challenge_catalog.dart';
import 'models/challenge_contribution.dart';
import 'models/challenge_evidence_quality.dart';
import 'models/challenge_metric.dart';

/// Why a completed session cannot contribute to medal progress.
enum ChallengeContributionRejectionReason {
  unsupportedExercise,
  untrustedEvidence,
  analysisKindMismatch,
  nonPositiveMetric,
  invalidMetric,
}

/// Accepted contribution or an explicit rejection reason.
class ChallengeContributionEvaluation {
  const ChallengeContributionEvaluation.accepted(
    ChallengeContribution contribution,
  ) : this._(contribution: contribution, rejectionReason: null);

  const ChallengeContributionEvaluation.rejected(
    ChallengeContributionRejectionReason rejectionReason,
  ) : this._(contribution: null, rejectionReason: rejectionReason);

  const ChallengeContributionEvaluation._({
    required this.contribution,
    required this.rejectionReason,
  });

  final ChallengeContribution? contribution;
  final ChallengeContributionRejectionReason? rejectionReason;

  bool get isAccepted => contribution != null;
}

/// Converts persisted workout evidence into strict V1 challenge progress.
class ChallengeContributionEvaluator {
  const ChallengeContributionEvaluator({
    this.catalog = const ChallengeCatalog(),
  });

  final ChallengeCatalog catalog;

  ChallengeContributionEvaluation evaluate({
    required WorkoutSession session,
    required Duration timezoneOffset,
  }) {
    final definition = catalog.definitionForExerciseId(session.exerciseType);
    if (definition == null) {
      return const ChallengeContributionEvaluation.rejected(
        ChallengeContributionRejectionReason.unsupportedExercise,
      );
    }

    if (!_hasTrustedEvidence(session.measurementQuality)) {
      return const ChallengeContributionEvaluation.rejected(
        ChallengeContributionRejectionReason.untrustedEvidence,
      );
    }

    if (session.analysisKind != definition.metric.requiredAnalysisKind) {
      return const ChallengeContributionEvaluation.rejected(
        ChallengeContributionRejectionReason.analysisKindMismatch,
      );
    }

    final value = switch (definition.metric) {
      ChallengeMetric.validRepetitions => session.validReps.toDouble(),
      ChallengeMetric.trustedHoldSeconds => session.totalHoldSeconds,
    };

    if (!value.isFinite) {
      return const ChallengeContributionEvaluation.rejected(
        ChallengeContributionRejectionReason.invalidMetric,
      );
    }
    if (value <= 0) {
      return const ChallengeContributionEvaluation.rejected(
        ChallengeContributionRejectionReason.nonPositiveMetric,
      );
    }

    return ChallengeContributionEvaluation.accepted(
      ChallengeContribution(
        sessionId: session.id,
        challengeId: definition.id,
        catalogVersion: definition.catalogVersion,
        exerciseType: definition.exerciseType,
        metric: definition.metric,
        evidenceQuality: _evidenceQuality(session.measurementQuality),
        value: value,
        endedAt: session.endedAt,
        timezoneOffset: timezoneOffset,
      ),
    );
  }
}

ChallengeEvidenceQuality _evidenceQuality(SessionMeasurementQuality quality) {
  return switch (quality) {
    SessionMeasurementQuality.high => ChallengeEvidenceQuality.high,
    SessionMeasurementQuality.moderate => ChallengeEvidenceQuality.moderate,
    _ => throw StateError('Untrusted evidence cannot create a contribution.'),
  };
}

bool _hasTrustedEvidence(SessionMeasurementQuality quality) {
  return quality == SessionMeasurementQuality.high ||
      quality == SessionMeasurementQuality.moderate;
}
