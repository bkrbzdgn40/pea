import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/achievements/application/outbox/achievement_event_outbox.dart';
import 'package:pose_estimation_app/features/achievements/domain/models/achievement_event.dart';
import 'package:pose_estimation_app/features/achievements/infrastructure/local/shared_preferences_achievement_event_outbox.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SharedPreferencesAchievementEventOutbox', () {
    const outbox = SharedPreferencesAchievementEventOutbox();

    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('persists pending events until explicitly removed', () async {
      final pending = PendingAchievementEvent(
        ownerId: 'user-1',
        event: AchievementEvent.plannedWorkoutCompleted(
          planRunId: 'plan_run_1',
          occurredAt: DateTime.utc(2026, 8, 7, 8),
        ),
        timezoneOffset: const Duration(hours: 3),
      );

      await outbox.enqueue(pending);
      final restored = await outbox.listPending(ownerId: 'user-1');

      expect(restored, hasLength(1));
      expect(restored.single.id, pending.id);
      expect(restored.single.timezoneOffset, const Duration(hours: 3));
      expect(restored.single.event.occurredAtUtc, DateTime.utc(2026, 8, 7, 8));

      await outbox.remove(ownerId: 'user-1', eventId: pending.id);
      expect(await outbox.listPending(ownerId: 'user-1'), isEmpty);
    });

    test('keeps users isolated and overwrites duplicate event ids', () async {
      await outbox.enqueue(
        PendingAchievementEvent(
          ownerId: 'user-1',
          event: AchievementEvent.guideStepOpened(
            stepId: '1',
            occurredAt: DateTime.utc(2026, 8, 7, 8),
          ),
          timezoneOffset: Duration.zero,
        ),
      );
      await outbox.enqueue(
        PendingAchievementEvent(
          ownerId: 'user-1',
          event: AchievementEvent.guideStepOpened(
            stepId: '1',
            occurredAt: DateTime.utc(2026, 8, 7, 9),
          ),
          timezoneOffset: Duration.zero,
        ),
      );
      await outbox.enqueue(
        PendingAchievementEvent(
          ownerId: 'user-2',
          event: AchievementEvent.guideStepOpened(
            stepId: '1',
            occurredAt: DateTime.utc(2026, 8, 7, 10),
          ),
          timezoneOffset: Duration.zero,
        ),
      );

      final firstUser = await outbox.listPending(ownerId: 'user-1');
      final secondUser = await outbox.listPending(ownerId: 'user-2');
      expect(firstUser, hasLength(1));
      expect(firstUser.single.event.occurredAtUtc, DateTime.utc(2026, 8, 7, 9));
      expect(secondUser, hasLength(1));
    });
  });
}
