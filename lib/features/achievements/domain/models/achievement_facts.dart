import '../../../workout_analysis/domain/models/exercise_type.dart';
import 'achievement_body_region.dart';

class AchievementFacts {
  const AchievementFacts({
    this.reliableSessionIds = const <String>{},
    this.reliableExerciseTypes = const <ExerciseType>{},
    this.reliableBodyRegions = const <AchievementBodyRegion>{},
    this.openedGuideStepIds = const <String>{},
    this.controlledTempoSessionIds = const <String>{},
    this.completedPlanRunIds = const <String>{},
    this.qualifiedLocalDayKeys = const <String>{},
    this.weeklyMedalExerciseIdsByWeek = const <String, Set<ExerciseType>>{},
  });

  final Set<String> reliableSessionIds;
  final Set<ExerciseType> reliableExerciseTypes;
  final Set<AchievementBodyRegion> reliableBodyRegions;
  final Set<String> openedGuideStepIds;
  final Set<String> controlledTempoSessionIds;
  final Set<String> completedPlanRunIds;
  final Set<String> qualifiedLocalDayKeys;
  final Map<String, Set<ExerciseType>> weeklyMedalExerciseIdsByWeek;
}
