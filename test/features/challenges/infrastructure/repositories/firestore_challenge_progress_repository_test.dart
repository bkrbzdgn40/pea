import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/core/firebase/firestore_paths.dart';
import 'package:pose_estimation_app/features/challenges/domain/models/challenge_contribution.dart';
import 'package:pose_estimation_app/features/challenges/domain/models/challenge_evidence_quality.dart';
import 'package:pose_estimation_app/features/challenges/domain/models/challenge_metric.dart';
import 'package:pose_estimation_app/features/challenges/domain/models/challenge_progress_mutation.dart';
import 'package:pose_estimation_app/features/challenges/infrastructure/repositories/firestore_challenge_progress_repository.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_type.dart';

void main() {
  group('FirestoreChallengeProgressRepository', () {
    late FakeFirebaseFirestore firestore;
    late FirestoreChallengeProgressRepository repository;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      repository = FirestoreChallengeProgressRepository(firestore);
    });

    test(
      'creates one contribution and does not count an identical retry',
      () async {
        final contribution = _contribution(
          sessionId: 'session-1',
          exerciseType: ExerciseType.pushUp,
          metric: ChallengeMetric.validRepetitions,
          value: 12,
          quality: ChallengeEvidenceQuality.high,
        );

        final created = await repository.upsertContribution(
          ownerId: 'user-1',
          contribution: contribution,
          now: DateTime.utc(2026, 8, 6, 21, 1),
        );
        final unchanged = await repository.upsertContribution(
          ownerId: 'user-1',
          contribution: contribution,
          now: DateTime.utc(2026, 8, 6, 21, 2),
        );
        final day = await repository.getActivityDay(
          ownerId: 'user-1',
          localDate: '2026-08-07',
        );
        final record = await repository.getContribution(
          ownerId: 'user-1',
          sessionId: 'session-1',
        );

        expect(created.status, ChallengeContributionWriteStatus.created);
        expect(unchanged.status, ChallengeContributionWriteStatus.unchanged);
        expect(day?.trustedSessionCount, 1);
        expect(day?.highReliabilitySessionCount, 1);
        expect(day?.validRepsByExercise[ExerciseType.pushUp], 12);
        expect(record?.updatedAtUtc, DateTime.utc(2026, 8, 6, 21, 1));
      },
    );

    test(
      'does not hide a missing aggregate behind an idempotent retry',
      () async {
        final contribution = _contribution(
          sessionId: 'session-1',
          exerciseType: ExerciseType.pushUp,
          metric: ChallengeMetric.validRepetitions,
          value: 12,
          quality: ChallengeEvidenceQuality.high,
        );

        await repository.upsertContribution(
          ownerId: 'user-1',
          contribution: contribution,
          now: DateTime.utc(2026, 8, 6, 21, 1),
        );
        await firestore
            .doc(FirestorePaths.userActivityDayDoc('user-1', '2026-08-07'))
            .delete();

        expect(
          () => repository.upsertContribution(
            ownerId: 'user-1',
            contribution: contribution,
            now: DateTime.utc(2026, 8, 6, 21, 2),
          ),
          throwsStateError,
        );
      },
    );

    test('replaces a changed contribution without double counting', () async {
      final original = _contribution(
        sessionId: 'session-1',
        exerciseType: ExerciseType.pushUp,
        metric: ChallengeMetric.validRepetitions,
        value: 12,
        quality: ChallengeEvidenceQuality.high,
      );
      final corrected = _contribution(
        sessionId: 'session-1',
        exerciseType: ExerciseType.pushUp,
        metric: ChallengeMetric.validRepetitions,
        value: 8,
        quality: ChallengeEvidenceQuality.moderate,
      );

      await repository.upsertContribution(
        ownerId: 'user-1',
        contribution: original,
        now: DateTime.utc(2026, 8, 6, 21, 1),
      );
      final result = await repository.upsertContribution(
        ownerId: 'user-1',
        contribution: corrected,
        now: DateTime.utc(2026, 8, 6, 21, 2),
      );
      final day = await repository.getActivityDay(
        ownerId: 'user-1',
        localDate: '2026-08-07',
      );

      expect(result.status, ChallengeContributionWriteStatus.replaced);
      expect(day?.trustedSessionCount, 1);
      expect(day?.highReliabilitySessionCount, 0);
      expect(day?.validRepsByExercise[ExerciseType.pushUp], 8);
    });

    test('moves a corrected contribution to its new local date', () async {
      final original = _contribution(
        sessionId: 'session-1',
        exerciseType: ExerciseType.pushUp,
        metric: ChallengeMetric.validRepetitions,
        value: 10,
        quality: ChallengeEvidenceQuality.high,
      );
      final moved = _contribution(
        sessionId: 'session-1',
        exerciseType: ExerciseType.pushUp,
        metric: ChallengeMetric.validRepetitions,
        value: 10,
        quality: ChallengeEvidenceQuality.high,
        endedAt: DateTime.utc(2026, 8, 7, 22),
      );

      await repository.upsertContribution(
        ownerId: 'user-1',
        contribution: original,
        now: DateTime.utc(2026, 8, 6, 21, 1),
      );
      final result = await repository.upsertContribution(
        ownerId: 'user-1',
        contribution: moved,
        now: DateTime.utc(2026, 8, 7, 22, 1),
      );

      expect(result.affectedLocalDates, <String>{'2026-08-07', '2026-08-08'});
      expect(
        await repository.getActivityDay(
          ownerId: 'user-1',
          localDate: '2026-08-07',
        ),
        isNull,
      );
      expect(
        (await repository.getActivityDay(
          ownerId: 'user-1',
          localDate: '2026-08-08',
        ))?.validRepsByExercise[ExerciseType.pushUp],
        10,
      );
    });

    test(
      'aggregates sessions and removes each contribution exactly once',
      () async {
        final pushUp = _contribution(
          sessionId: 'session-1',
          exerciseType: ExerciseType.pushUp,
          metric: ChallengeMetric.validRepetitions,
          value: 10,
          quality: ChallengeEvidenceQuality.high,
        );
        final plank = _contribution(
          sessionId: 'session-2',
          exerciseType: ExerciseType.plank,
          metric: ChallengeMetric.trustedHoldSeconds,
          value: 45,
          quality: ChallengeEvidenceQuality.moderate,
        );

        await repository.upsertContribution(
          ownerId: 'user-1',
          contribution: pushUp,
          now: DateTime.utc(2026, 8, 6, 21, 1),
        );
        await repository.upsertContribution(
          ownerId: 'user-1',
          contribution: plank,
          now: DateTime.utc(2026, 8, 6, 21, 2),
        );

        expect(
          await repository.removeContribution(
            ownerId: 'user-1',
            sessionId: 'session-1',
            now: DateTime.utc(2026, 8, 6, 21, 3),
          ),
          isTrue,
        );
        expect(
          await repository.removeContribution(
            ownerId: 'user-1',
            sessionId: 'session-1',
            now: DateTime.utc(2026, 8, 6, 21, 4),
          ),
          isFalse,
        );
        final remaining = await repository.getActivityDay(
          ownerId: 'user-1',
          localDate: '2026-08-07',
        );
        expect(remaining?.trustedSessionCount, 1);
        expect(remaining?.validRepsByExercise, isEmpty);
        expect(remaining?.holdSecondsByExercise[ExerciseType.plank], 45);

        await repository.removeContribution(
          ownerId: 'user-1',
          sessionId: 'session-2',
          now: DateTime.utc(2026, 8, 6, 21, 5),
        );
        expect(
          await repository.getActivityDay(
            ownerId: 'user-1',
            localDate: '2026-08-07',
          ),
          isNull,
        );
      },
    );

    test('lists persisted contributions in chronological order', () async {
      await repository.upsertContribution(
        ownerId: 'user-1',
        contribution: _contribution(
          sessionId: 'session-late',
          exerciseType: ExerciseType.pushUp,
          metric: ChallengeMetric.validRepetitions,
          value: 12,
          quality: ChallengeEvidenceQuality.high,
          endedAt: DateTime.utc(2026, 8, 7, 10),
        ),
        now: DateTime.utc(2026, 8, 7, 10, 1),
      );
      await repository.upsertContribution(
        ownerId: 'user-1',
        contribution: _contribution(
          sessionId: 'session-early',
          exerciseType: ExerciseType.pushUp,
          metric: ChallengeMetric.validRepetitions,
          value: 8,
          quality: ChallengeEvidenceQuality.moderate,
          endedAt: DateTime.utc(2026, 8, 7, 8),
        ),
        now: DateTime.utc(2026, 8, 7, 8, 1),
      );

      final records = await repository.listContributions(ownerId: 'user-1');
      final day = await repository.getActivityDay(
        ownerId: 'user-1',
        localDate: '2026-08-07',
      );

      expect(
        records.map((record) => record.id).toList(growable: false),
        <String>['session-early', 'session-late'],
      );
      expect(day?.trustedSessionCount, 2);
      expect(day?.validRepsByExercise[ExerciseType.pushUp], 20);
      expect(day?.createdAtUtc, DateTime.utc(2026, 8, 7, 10, 1));
      expect(day?.updatedAtUtc, DateTime.utc(2026, 8, 7, 10, 1));
    });

    test('lists only activity days inside the requested range', () async {
      for (final entry in <(String, DateTime)>[
        ('session-1', DateTime.utc(2026, 8, 5, 20)),
        ('session-2', DateTime.utc(2026, 8, 6, 20)),
        ('session-3', DateTime.utc(2026, 8, 7, 20)),
      ]) {
        await repository.upsertContribution(
          ownerId: 'user-1',
          contribution: _contribution(
            sessionId: entry.$1,
            exerciseType: ExerciseType.pushUp,
            metric: ChallengeMetric.validRepetitions,
            value: 10,
            quality: ChallengeEvidenceQuality.high,
            endedAt: entry.$2,
          ),
          now: entry.$2,
        );
      }

      final days = await repository.listActivityDays(
        ownerId: 'user-1',
        startLocalDateInclusive: '2026-08-06',
        endLocalDateExclusive: '2026-08-08',
      );

      expect(days.map((day) => day.localDate), <String>[
        '2026-08-06',
        '2026-08-07',
      ]);
    });
  });
}

ChallengeContribution _contribution({
  required String sessionId,
  required ExerciseType exerciseType,
  required ChallengeMetric metric,
  required double value,
  required ChallengeEvidenceQuality quality,
  DateTime? endedAt,
}) {
  return ChallengeContribution(
    sessionId: sessionId,
    challengeId: '${exerciseType.id}_volume',
    catalogVersion: 1,
    exerciseType: exerciseType,
    metric: metric,
    evidenceQuality: quality,
    value: value,
    endedAt: endedAt ?? DateTime.utc(2026, 8, 6, 21),
    timezoneOffset: const Duration(hours: 3),
  );
}
