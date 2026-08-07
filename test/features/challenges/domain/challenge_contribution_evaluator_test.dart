import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/challenges/domain/challenge_contribution_evaluator.dart';
import 'package:pose_estimation_app/features/challenges/domain/models/challenge_evidence_quality.dart';
import 'package:pose_estimation_app/features/challenges/domain/models/challenge_metric.dart';
import 'package:pose_estimation_app/features/challenges/domain/models/challenge_period.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/session_measurement_evidence.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/workout_session.dart';

void main() {
  const evaluator = ChallengeContributionEvaluator();
  const timezoneOffset = Duration(hours: 3);

  group('ChallengeContributionEvaluator', () {
    test('uses valid reps rather than total or low-confidence reps', () {
      final result = evaluator.evaluate(
        session: _session(
          exerciseType: 'push_up',
          totalReps: 12,
          validReps: 8,
          lowConfidenceReps: 4,
          quality: SessionMeasurementQuality.high,
        ),
        timezoneOffset: timezoneOffset,
      );

      expect(result.isAccepted, isTrue);
      expect(result.rejectionReason, isNull);
      expect(result.contribution?.challengeId, 'push_up_volume');
      expect(result.contribution?.catalogVersion, 1);
      expect(result.contribution?.metric, ChallengeMetric.validRepetitions);
      expect(
        result.contribution?.evidenceQuality,
        ChallengeEvidenceQuality.high,
      );
      expect(result.contribution?.value, 8);
      expect(
        result.contribution?.windowFor(ChallengePeriod.daily).key,
        '2026-08-07',
      );
    });

    test('accepts moderate evidence and hold seconds', () {
      final result = evaluator.evaluate(
        session: _session(
          exerciseType: 'plank',
          analysisKind: 'hold',
          totalReps: 0,
          validReps: 0,
          totalHoldSeconds: 42.5,
          quality: SessionMeasurementQuality.moderate,
        ),
        timezoneOffset: timezoneOffset,
      );

      expect(result.isAccepted, isTrue);
      expect(result.contribution?.metric, ChallengeMetric.trustedHoldSeconds);
      expect(
        result.contribution?.evidenceQuality,
        ChallengeEvidenceQuality.moderate,
      );
      expect(result.contribution?.value, 42.5);
    });

    test('rejects limited, insufficient, and unknown evidence', () {
      for (final quality in <SessionMeasurementQuality>[
        SessionMeasurementQuality.limited,
        SessionMeasurementQuality.insufficient,
        SessionMeasurementQuality.unknown,
      ]) {
        final result = evaluator.evaluate(
          session: _session(
            exerciseType: 'push_up',
            totalReps: 10,
            validReps: 10,
            quality: quality,
          ),
          timezoneOffset: timezoneOffset,
        );

        expect(result.isAccepted, isFalse, reason: quality.name);
        expect(
          result.rejectionReason,
          ChallengeContributionRejectionReason.untrustedEvidence,
          reason: quality.name,
        );
      }
    });

    test('rejects unknown exercises and mismatched analysis kinds', () {
      final unknown = evaluator.evaluate(
        session: _session(
          exerciseType: 'burpee',
          totalReps: 10,
          validReps: 10,
          quality: SessionMeasurementQuality.high,
        ),
        timezoneOffset: timezoneOffset,
      );
      final mismatch = evaluator.evaluate(
        session: _session(
          exerciseType: 'plank',
          analysisKind: 'rangeRep',
          totalReps: 10,
          validReps: 10,
          quality: SessionMeasurementQuality.high,
        ),
        timezoneOffset: timezoneOffset,
      );

      expect(
        unknown.rejectionReason,
        ChallengeContributionRejectionReason.unsupportedExercise,
      );
      expect(
        mismatch.rejectionReason,
        ChallengeContributionRejectionReason.analysisKindMismatch,
      );
    });

    test('rejects empty trusted volume', () {
      final result = evaluator.evaluate(
        session: _session(
          exerciseType: 'push_up',
          totalReps: 4,
          validReps: 0,
          lowConfidenceReps: 4,
          quality: SessionMeasurementQuality.high,
        ),
        timezoneOffset: timezoneOffset,
      );

      expect(
        result.rejectionReason,
        ChallengeContributionRejectionReason.nonPositiveMetric,
      );
    });

    test('rejects non-finite hold duration', () {
      final result = evaluator.evaluate(
        session: _session(
          exerciseType: 'plank',
          analysisKind: 'hold',
          totalReps: 0,
          validReps: 0,
          totalHoldSeconds: double.nan,
          quality: SessionMeasurementQuality.high,
        ),
        timezoneOffset: timezoneOffset,
      );

      expect(
        result.rejectionReason,
        ChallengeContributionRejectionReason.invalidMetric,
      );
    });
  });
}

WorkoutSession _session({
  required String exerciseType,
  String analysisKind = 'rangeRep',
  required int totalReps,
  required int validReps,
  int lowConfidenceReps = 0,
  double totalHoldSeconds = 0,
  required SessionMeasurementQuality quality,
}) {
  final evidence = switch (quality) {
    SessionMeasurementQuality.high || SessionMeasurementQuality.moderate => (
      preparationOutcome: PreparationOutcome.passed,
      confidence: 0.95,
      samples: 5,
    ),
    SessionMeasurementQuality.limited => (
      preparationOutcome: PreparationOutcome.overridden,
      confidence: 0.55,
      samples: 5,
    ),
    SessionMeasurementQuality.insufficient => (
      preparationOutcome: PreparationOutcome.overridden,
      confidence: 0.4,
      samples: 1,
    ),
    SessionMeasurementQuality.unknown => (
      preparationOutcome: PreparationOutcome.legacyUnknown,
      confidence: null,
      samples: 0,
    ),
  };

  return WorkoutSession(
    id: 'session-1',
    ownerId: 'user-1',
    exerciseType: exerciseType,
    analysisKind: analysisKind,
    startedAt: DateTime.utc(2026, 8, 6, 21),
    endedAt: DateTime.utc(2026, 8, 6, 21, 30),
    durationSec: 30,
    totalReps: totalReps,
    averageScore: 80,
    bestScore: 90,
    validReps: validReps,
    lowConfidenceReps: lowConfidenceReps,
    formWarningCount: 0,
    totalHoldSeconds: totalHoldSeconds,
    preparationOutcome: evidence.preparationOutcome,
    measurementQuality: quality,
    averageMeasurementConfidence: evidence.confidence,
    measurementSampleCount: evidence.samples,
  );
}
