import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/session_measurement_evidence.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/session_evidence_eligibility_policy.dart';

import '../../../support/workout_statistics_test_support.dart';

void main() {
  const policy = SessionEvidenceEligibilityPolicy();

  test('trusted evidence contributes to every progress calculation', () {
    final session = buildWorkoutSession(
      id: 'trusted',
      startedAt: DateTime(2024, 1, 1),
      totalReps: 10,
      averageScore: 88,
      preparationOutcome: PreparationOutcome.passed,
      measurementQuality: SessionMeasurementQuality.high,
      averageMeasurementConfidence: 0.94,
      measurementSampleCount: 10,
    );

    expect(policy.appearsInScoreTrend(session), isTrue);
    expect(policy.contributesToScoreAggregates(session), isTrue);
    expect(policy.contributesToRepetitionVolume(session), isTrue);
    expect(policy.countsAsCompletedSession(session), isTrue);
  });

  test('limited evidence stays visible in trend but not progress totals', () {
    final session = buildWorkoutSession(
      id: 'limited',
      startedAt: DateTime(2024, 1, 2),
      totalReps: 12,
      averageScore: 96,
      preparationOutcome: PreparationOutcome.passed,
      measurementQuality: SessionMeasurementQuality.limited,
      averageMeasurementConfidence: 0.71,
      measurementSampleCount: 12,
    );

    expect(policy.appearsInScoreTrend(session), isTrue);
    expect(policy.contributesToScoreAggregates(session), isFalse);
    expect(policy.contributesToRepetitionVolume(session), isFalse);
    expect(policy.countsAsCompletedSession(session), isTrue);
  });

  test('insufficient evidence is excluded from trend and progress totals', () {
    final session = buildWorkoutSession(
      id: 'insufficient',
      startedAt: DateTime(2024, 1, 3),
      totalReps: 1,
      averageScore: 100,
      preparationOutcome: PreparationOutcome.passed,
      measurementQuality: SessionMeasurementQuality.insufficient,
      averageMeasurementConfidence: 0.99,
      measurementSampleCount: 1,
    );

    expect(policy.appearsInScoreTrend(session), isFalse);
    expect(policy.contributesToScoreAggregates(session), isFalse);
    expect(policy.contributesToRepetitionVolume(session), isFalse);
    expect(policy.countsAsCompletedSession(session), isTrue);
  });

  test('legacy sessions keep previous score and repetition behavior', () {
    final session = buildWorkoutSession(
      id: 'legacy',
      startedAt: DateTime(2024, 1, 4),
      totalReps: 8,
      averageScore: 82,
    );

    expect(policy.appearsInScoreTrend(session), isTrue);
    expect(policy.contributesToScoreAggregates(session), isTrue);
    expect(policy.contributesToRepetitionVolume(session), isTrue);
  });

  test('new passed session without evidence does not claim progress', () {
    final session = buildWorkoutSession(
      id: 'missing-evidence',
      startedAt: DateTime(2024, 1, 5),
      totalReps: 8,
      averageScore: 82,
      preparationOutcome: PreparationOutcome.passed,
    );

    expect(policy.appearsInScoreTrend(session), isFalse);
    expect(policy.contributesToScoreAggregates(session), isFalse);
    expect(policy.contributesToRepetitionVolume(session), isFalse);
  });
}
