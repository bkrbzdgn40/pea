import '../../challenges/domain/models/challenge_contribution_record.dart';
import '../../challenges/domain/models/challenge_metric.dart';
import '../../rewards/domain/models/challenge_medal_reward.dart';
import '../../workout_analysis/application/exercise_definition_metadata.dart';
import '../../workout_analysis/domain/models/exercise_type.dart';
import '../domain/achievement_event_accumulator.dart';
import '../domain/models/achievement_body_region.dart';
import '../domain/models/achievement_event.dart';
import '../domain/models/achievement_event_record.dart';
import '../domain/models/achievement_facts.dart';

class RuntimeAchievementFactsBuilder {
  const RuntimeAchievementFactsBuilder();

  AchievementFacts build({
    required Iterable<ChallengeContributionRecord> contributions,
    required Iterable<AchievementEventRecord> events,
    required Iterable<ChallengeMedalReward> weeklyMedals,
  }) {
    final reliableSessionIds = <String>{};
    final reliableExerciseTypes = <ExerciseType>{};
    final reliableBodyRegions = <AchievementBodyRegion>{};
    final repVolumeByDay = <String, int>{};
    final holdSecondsByDay = <String, double>{};

    for (final record in contributions) {
      final contribution = record.contribution;
      reliableSessionIds.add(contribution.sessionId);
      reliableExerciseTypes.add(contribution.exerciseType);
      reliableBodyRegions.add(
        _achievementRegion(contribution.exerciseType.bodyRegion),
      );
      switch (contribution.metric) {
        case ChallengeMetric.validRepetitions:
          repVolumeByDay.update(
            record.localDate,
            (value) => value + contribution.value.toInt(),
            ifAbsent: () => contribution.value.toInt(),
          );
        case ChallengeMetric.trustedHoldSeconds:
          holdSecondsByDay.update(
            record.localDate,
            (value) => value + contribution.value,
            ifAbsent: () => contribution.value,
          );
      }
    }

    final qualifiedDays = <String>{};
    for (final day in <String>{
      ...repVolumeByDay.keys,
      ...holdSecondsByDay.keys,
    }) {
      if ((repVolumeByDay[day] ?? 0) >= 5 ||
          (holdSecondsByDay[day] ?? 0) >= 20) {
        qualifiedDays.add(day);
      }
    }

    final weeklyByWeek = <String, Set<ExerciseType>>{};
    for (final reward in weeklyMedals) {
      weeklyByWeek
          .putIfAbsent(reward.periodKey, () => <ExerciseType>{})
          .add(reward.exerciseType);
    }

    final eventRecords = events.toList(growable: false);
    for (final record in eventRecords) {
      if (record.event.type == AchievementEventType.plannedWorkoutCompleted) {
        qualifiedDays.add(record.localDate);
      }
    }

    final base = AchievementFacts(
      reliableSessionIds: reliableSessionIds,
      reliableExerciseTypes: reliableExerciseTypes,
      reliableBodyRegions: reliableBodyRegions,
      qualifiedLocalDayKeys: qualifiedDays,
      weeklyMedalExerciseIdsByWeek: weeklyByWeek,
    );
    final accumulated = const AchievementEventAccumulator().apply(
      base,
      eventRecords.map((record) => record.event),
    );
    return AchievementFacts(
      reliableSessionIds: accumulated.reliableSessionIds,
      reliableExerciseTypes: accumulated.reliableExerciseTypes,
      reliableBodyRegions: accumulated.reliableBodyRegions,
      openedGuideStepIds: accumulated.openedGuideStepIds,
      controlledTempoSessionIds: accumulated.controlledTempoSessionIds
          .intersection(accumulated.reliableSessionIds),
      completedPlanRunIds: accumulated.completedPlanRunIds,
      qualifiedLocalDayKeys: accumulated.qualifiedLocalDayKeys,
      weeklyMedalExerciseIdsByWeek: accumulated.weeklyMedalExerciseIdsByWeek,
    );
  }

  AchievementBodyRegion _achievementRegion(ExerciseBodyRegion region) {
    return switch (region) {
      ExerciseBodyRegion.lowerBody => AchievementBodyRegion.lowerBody,
      ExerciseBodyRegion.upperBody => AchievementBodyRegion.upperBody,
      ExerciseBodyRegion.core => AchievementBodyRegion.core,
      ExerciseBodyRegion.fullBody => AchievementBodyRegion.fullBody,
    };
  }
}
