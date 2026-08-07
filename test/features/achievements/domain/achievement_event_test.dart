import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/achievements/domain/models/achievement_event.dart';

void main() {
  group('AchievementEvent', () {
    test('uses deterministic ids for runtime events', () {
      final guide = AchievementEvent.guideStepOpened(
        stepId: '3',
        occurredAt: DateTime.utc(2026, 8, 7),
      );
      final plan = AchievementEvent.plannedWorkoutCompleted(
        planRunId: 'plan_run_1',
        occurredAt: DateTime.utc(2026, 8, 7),
      );
      final tempo = AchievementEvent.controlledTempoSession(
        sessionId: 'session_1',
        occurredAt: DateTime.utc(2026, 8, 7),
      );

      expect(guide.eventId, 'guide-step:3');
      expect(plan.eventId, 'planned-workout:plan_run_1');
      expect(tempo.eventId, 'controlled-tempo:session_1');
    });

    test('rejects guide steps outside the V1 guide contract', () {
      expect(
        () => AchievementEvent.guideStepOpened(
          stepId: '7',
          occurredAt: DateTime.utc(2026, 8, 7),
        ),
        throwsArgumentError,
      );
    });

    test('rejects non-canonical generic event ids', () {
      expect(
        () => AchievementEvent(
          eventId: 'wrong',
          type: AchievementEventType.controlledTempoSession,
          subjectId: 'session_1',
          occurredAt: DateTime.utc(2026, 8, 7),
        ),
        throwsArgumentError,
      );
    });
  });
}
