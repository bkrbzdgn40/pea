import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/achievements/application/repositories/achievement_event_repository.dart';
import 'package:pose_estimation_app/features/achievements/domain/models/achievement_event.dart';
import 'package:pose_estimation_app/features/achievements/infrastructure/repositories/firestore_achievement_event_repository.dart';

void main() {
  group('FirestoreAchievementEventRepository', () {
    late FakeFirebaseFirestore firestore;
    late FirestoreAchievementEventRepository repository;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      repository = FirestoreAchievementEventRepository(firestore);
    });

    test(
      'records one deterministic guide event and deduplicates reopen',
      () async {
        final first = await repository.recordEvent(
          ownerId: 'user-1',
          event: AchievementEvent.guideStepOpened(
            stepId: '1',
            occurredAt: DateTime.utc(2026, 8, 7, 8),
          ),
          timezoneOffset: const Duration(hours: 3),
          now: DateTime.utc(2026, 8, 7, 8, 1),
        );
        final duplicate = await repository.recordEvent(
          ownerId: 'user-1',
          event: AchievementEvent.guideStepOpened(
            stepId: '1',
            occurredAt: DateTime.utc(2026, 8, 7, 10),
          ),
          timezoneOffset: const Duration(hours: 3),
          now: DateTime.utc(2026, 8, 7, 10, 1),
        );

        expect(first.status, AchievementEventWriteStatus.created);
        expect(duplicate.status, AchievementEventWriteStatus.unchanged);
        expect(
          duplicate.record.event.occurredAtUtc,
          DateTime.utc(2026, 8, 7, 8),
        );
        expect((await repository.listEvents(ownerId: 'user-1')), hasLength(1));
      },
    );

    test('captures the local calendar date at event time', () async {
      final result = await repository.recordEvent(
        ownerId: 'user-1',
        event: AchievementEvent.plannedWorkoutCompleted(
          planRunId: 'plan_run_1',
          occurredAt: DateTime.utc(2026, 8, 6, 22, 30),
        ),
        timezoneOffset: const Duration(hours: 3),
        now: DateTime.utc(2026, 8, 6, 22, 31),
      );

      expect(result.record.localDate, '2026-08-07');
      expect(result.record.timezoneOffset, const Duration(hours: 3));
    });
  });
}
