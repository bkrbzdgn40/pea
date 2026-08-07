import 'models/achievement_event.dart';
import 'models/achievement_facts.dart';

class AchievementEventAccumulator {
  const AchievementEventAccumulator();

  AchievementFacts apply(
    AchievementFacts base,
    Iterable<AchievementEvent> events,
  ) {
    final guideSteps = <String>{...base.openedGuideStepIds};
    final planRuns = <String>{...base.completedPlanRunIds};
    final tempoSessions = <String>{...base.controlledTempoSessionIds};
    final seenEventIds = <String>{};

    for (final event in events) {
      if (!seenEventIds.add(event.eventId)) {
        continue;
      }
      switch (event.type) {
        case AchievementEventType.guideStepOpened:
          guideSteps.add(event.subjectId);
        case AchievementEventType.plannedWorkoutCompleted:
          planRuns.add(event.subjectId);
        case AchievementEventType.controlledTempoSession:
          tempoSessions.add(event.subjectId);
      }
    }

    return AchievementFacts(
      reliableSessionIds: base.reliableSessionIds,
      reliableExerciseTypes: base.reliableExerciseTypes,
      reliableBodyRegions: base.reliableBodyRegions,
      openedGuideStepIds: guideSteps,
      controlledTempoSessionIds: tempoSessions,
      completedPlanRunIds: planRuns,
      qualifiedLocalDayKeys: base.qualifiedLocalDayKeys,
      weeklyMedalExerciseIdsByWeek: base.weeklyMedalExerciseIdsByWeek,
    );
  }
}
