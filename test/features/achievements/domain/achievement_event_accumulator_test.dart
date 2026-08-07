import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/achievements/domain/achievement_event_accumulator.dart';
import 'package:pose_estimation_app/features/achievements/domain/models/achievement_event.dart';
import 'package:pose_estimation_app/features/achievements/domain/models/achievement_facts.dart';

void main() {
  test('guide and plan events are idempotent by event and subject id', () {
    final now = DateTime.utc(2026, 8, 7);
    final result = const AchievementEventAccumulator()
        .apply(const AchievementFacts(), [
          AchievementEvent.guideStepOpened(stepId: '1', occurredAt: now),
          AchievementEvent.guideStepOpened(stepId: '1', occurredAt: now),
          AchievementEvent.plannedWorkoutCompleted(
            planRunId: 'plan-run-1',
            occurredAt: now,
          ),
          AchievementEvent.plannedWorkoutCompleted(
            planRunId: 'plan-run-1',
            occurredAt: now,
          ),
        ]);

    expect(result.openedGuideStepIds, {'1'});
    expect(result.completedPlanRunIds, {'plan-run-1'});
  });

  test('controlled tempo events retain unique session ids', () {
    final now = DateTime.utc(2026, 8, 7);
    final result = const AchievementEventAccumulator()
        .apply(const AchievementFacts(), [
          AchievementEvent.controlledTempoSession(
            sessionId: 'session-1',
            occurredAt: now,
          ),
          AchievementEvent.controlledTempoSession(
            sessionId: 'session-1',
            occurredAt: now,
          ),
        ]);

    expect(result.controlledTempoSessionIds, {'session-1'});
  });
}
