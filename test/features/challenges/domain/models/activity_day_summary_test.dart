import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/challenges/domain/models/activity_day_summary.dart';
import 'package:pose_estimation_app/features/challenges/domain/models/challenge_contribution.dart';
import 'package:pose_estimation_app/features/challenges/domain/models/challenge_evidence_quality.dart';
import 'package:pose_estimation_app/features/challenges/domain/models/challenge_metric.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_type.dart';

void main() {
  test('adds and removes rep and hold contributions without stale keys', () {
    final createdAt = DateTime.utc(2026, 8, 6, 20);
    final rep = _contribution(
      sessionId: 'rep-session',
      exerciseType: ExerciseType.pushUp,
      metric: ChallengeMetric.validRepetitions,
      value: 12,
      evidenceQuality: ChallengeEvidenceQuality.high,
    );
    final hold = _contribution(
      sessionId: 'hold-session',
      exerciseType: ExerciseType.plank,
      metric: ChallengeMetric.trustedHoldSeconds,
      value: 42.5,
      evidenceQuality: ChallengeEvidenceQuality.moderate,
    );

    final withRep = ActivityDaySummary.fromContribution(
      ownerId: 'user-1',
      contribution: rep,
      now: createdAt,
    );
    final withBoth = withRep.addContribution(
      hold,
      now: createdAt.add(const Duration(minutes: 1)),
    );

    expect(withBoth.trustedSessionCount, 2);
    expect(withBoth.highReliabilitySessionCount, 1);
    expect(withBoth.validRepsByExercise[ExerciseType.pushUp], 12);
    expect(withBoth.holdSecondsByExercise[ExerciseType.plank], 42.5);
    expect(withBoth.exerciseTypes, <ExerciseType>{
      ExerciseType.pushUp,
      ExerciseType.plank,
    });

    final withoutRep = withBoth.removeContribution(
      rep,
      now: createdAt.add(const Duration(minutes: 2)),
    );
    expect(withoutRep.trustedSessionCount, 1);
    expect(withoutRep.highReliabilitySessionCount, 0);
    expect(withoutRep.validRepsByExercise, isEmpty);
    expect(withoutRep.exerciseTypes, <ExerciseType>{ExerciseType.plank});

    final empty = withoutRep.removeContribution(
      hold,
      now: createdAt.add(const Duration(minutes: 3)),
    );
    expect(empty.isEmpty, isTrue);
  });

  test('keeps updatedAt monotonic when older activity is reconciled later', () {
    final createdAt = DateTime.utc(2026, 8, 7, 10, 1);
    final later = _contribution(
      sessionId: 'session-late',
      exerciseType: ExerciseType.pushUp,
      metric: ChallengeMetric.validRepetitions,
      value: 12,
      evidenceQuality: ChallengeEvidenceQuality.high,
      endedAt: DateTime.utc(2026, 8, 7, 10),
    );
    final earlier = _contribution(
      sessionId: 'session-early',
      exerciseType: ExerciseType.pushUp,
      metric: ChallengeMetric.validRepetitions,
      value: 8,
      evidenceQuality: ChallengeEvidenceQuality.moderate,
      endedAt: DateTime.utc(2026, 8, 7, 8),
    );

    final summary = ActivityDaySummary.fromContribution(
      ownerId: 'user-1',
      contribution: later,
      now: createdAt,
    );
    final reconciled = summary.addContribution(
      earlier,
      now: DateTime.utc(2026, 8, 7, 8, 1),
    );

    expect(reconciled.createdAtUtc, createdAt);
    expect(reconciled.updatedAtUtc, createdAt);
    expect(reconciled.trustedSessionCount, 2);
    expect(reconciled.validRepsByExercise[ExerciseType.pushUp], 20);
  });

  test('rejects a contribution from a different local date', () {
    final contribution = _contribution(
      sessionId: 'session-1',
      exerciseType: ExerciseType.pushUp,
      metric: ChallengeMetric.validRepetitions,
      value: 10,
      evidenceQuality: ChallengeEvidenceQuality.high,
    );
    final summary = ActivityDaySummary.fromContribution(
      ownerId: 'user-1',
      contribution: contribution,
      now: DateTime.utc(2026, 8, 6),
    );
    final nextDay = _contribution(
      sessionId: 'session-2',
      exerciseType: ExerciseType.pushUp,
      metric: ChallengeMetric.validRepetitions,
      value: 10,
      evidenceQuality: ChallengeEvidenceQuality.high,
      endedAt: DateTime.utc(2026, 8, 7, 22),
    );

    expect(
      () => summary.addContribution(nextDay, now: DateTime.utc(2026, 8, 7)),
      throwsArgumentError,
    );
  });
}

ChallengeContribution _contribution({
  required String sessionId,
  required ExerciseType exerciseType,
  required ChallengeMetric metric,
  required double value,
  required ChallengeEvidenceQuality evidenceQuality,
  DateTime? endedAt,
}) {
  return ChallengeContribution(
    sessionId: sessionId,
    challengeId: '${exerciseType.id}_volume',
    catalogVersion: 1,
    exerciseType: exerciseType,
    metric: metric,
    evidenceQuality: evidenceQuality,
    value: value,
    endedAt: endedAt ?? DateTime.utc(2026, 8, 6, 21),
    timezoneOffset: const Duration(hours: 3),
  );
}
