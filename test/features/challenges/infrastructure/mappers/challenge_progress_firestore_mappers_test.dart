import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/challenges/domain/models/activity_day_summary.dart';
import 'package:pose_estimation_app/features/challenges/domain/models/challenge_contribution.dart';
import 'package:pose_estimation_app/features/challenges/domain/models/challenge_contribution_record.dart';
import 'package:pose_estimation_app/features/challenges/domain/models/challenge_evidence_quality.dart';
import 'package:pose_estimation_app/features/challenges/domain/models/challenge_metric.dart';
import 'package:pose_estimation_app/features/challenges/infrastructure/mappers/activity_day_summary_firestore_mapper.dart';
import 'package:pose_estimation_app/features/challenges/infrastructure/mappers/challenge_contribution_firestore_mapper.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_type.dart';

void main() {
  const contributionMapper = ChallengeContributionFirestoreMapper();
  const activityDayMapper = ActivityDaySummaryFirestoreMapper();

  test('round-trips a contribution with stable local date metadata', () {
    final contribution = _contribution();
    final record = ChallengeContributionRecord(
      ownerId: 'user-1',
      contribution: contribution,
      createdAt: DateTime.utc(2026, 8, 6, 21, 1),
      updatedAt: DateTime.utc(2026, 8, 6, 21, 2),
    );

    final document = contributionMapper.toDocument(record);
    final decoded = contributionMapper.fromDocument(
      documentId: contribution.sessionId,
      data: document,
    );

    expect(document['value'], isA<int>());
    expect(decoded.ownerId, record.ownerId);
    expect(decoded.localDate, '2026-08-07');
    expect(decoded.contribution.hasSamePayloadAs(contribution), isTrue);
    expect(decoded.createdAtUtc, record.createdAtUtc);
    expect(decoded.updatedAtUtc, record.updatedAtUtc);
  });

  test('rejects a contribution whose stored local date is inconsistent', () {
    final contribution = _contribution();
    final record = ChallengeContributionRecord(
      ownerId: 'user-1',
      contribution: contribution,
      createdAt: DateTime.utc(2026, 8, 6, 21, 1),
      updatedAt: DateTime.utc(2026, 8, 6, 21, 2),
    );
    final document = contributionMapper.toDocument(record)
      ..['localDate'] = '2026-08-06';

    expect(
      () => contributionMapper.fromDocument(
        documentId: contribution.sessionId,
        data: document,
      ),
      throwsFormatException,
    );
  });

  test('round-trips an activity day and rejects stale exercise keys', () {
    final contribution = _contribution();
    final summary = ActivityDaySummary.fromContribution(
      ownerId: 'user-1',
      contribution: contribution,
      now: DateTime.utc(2026, 8, 6, 21, 1),
    );

    final document = activityDayMapper.toDocument(summary);
    final decoded = activityDayMapper.fromDocument(
      documentId: summary.localDate,
      data: document,
    );

    expect(decoded.validRepsByExercise[ExerciseType.pushUp], 12);
    expect(decoded.exerciseTypes, <ExerciseType>{ExerciseType.pushUp});

    document['exerciseTypes'] = <String>['push_up', 'plank'];
    expect(
      () => activityDayMapper.fromDocument(
        documentId: summary.localDate,
        data: document,
      ),
      throwsFormatException,
    );
  });
}

ChallengeContribution _contribution() {
  return ChallengeContribution(
    sessionId: 'session-1',
    challengeId: 'push_up_volume',
    catalogVersion: 1,
    exerciseType: ExerciseType.pushUp,
    metric: ChallengeMetric.validRepetitions,
    evidenceQuality: ChallengeEvidenceQuality.high,
    value: 12,
    endedAt: DateTime.utc(2026, 8, 6, 21),
    timezoneOffset: const Duration(hours: 3),
  );
}
