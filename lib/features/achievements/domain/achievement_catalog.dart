import 'models/achievement_definition.dart';
import 'models/achievement_visibility.dart';

class AchievementCatalog {
  const AchievementCatalog();

  static const int version = 1;

  static const AchievementDefinition firstReliableAnalysis =
      AchievementDefinition(
        id: 'first_reliable_analysis',
        definitionVersion: version,
        visibility: AchievementVisibility.visible,
        allowsHistoricalBackfill: true,
      );
  static const AchievementDefinition reliableSessions5 = AchievementDefinition(
    id: 'reliable_sessions_5',
    definitionVersion: version,
    visibility: AchievementVisibility.visible,
    allowsHistoricalBackfill: true,
  );
  static const AchievementDefinition exerciseExplorer3 = AchievementDefinition(
    id: 'exercise_explorer_3',
    definitionVersion: version,
    visibility: AchievementVisibility.visible,
    allowsHistoricalBackfill: true,
  );
  static const AchievementDefinition guideCompleted = AchievementDefinition(
    id: 'guide_completed',
    definitionVersion: version,
    visibility: AchievementVisibility.visible,
    allowsHistoricalBackfill: false,
  );
  static const AchievementDefinition controlledTempo = AchievementDefinition(
    id: 'controlled_tempo',
    definitionVersion: version,
    visibility: AchievementVisibility.visible,
    allowsHistoricalBackfill: false,
  );
  static const AchievementDefinition plannedWorkoutCompleted =
      AchievementDefinition(
        id: 'planned_workout_completed',
        definitionVersion: version,
        visibility: AchievementVisibility.visible,
        allowsHistoricalBackfill: false,
      );
  static const AchievementDefinition plannedWorkouts5 = AchievementDefinition(
    id: 'planned_workouts_5',
    definitionVersion: version,
    visibility: AchievementVisibility.visible,
    allowsHistoricalBackfill: false,
  );
  static const AchievementDefinition balancedExplorer = AchievementDefinition(
    id: 'balanced_explorer',
    definitionVersion: version,
    visibility: AchievementVisibility.visible,
    allowsHistoricalBackfill: true,
  );
  static const AchievementDefinition returnAfter14Days = AchievementDefinition(
    id: 'return_after_14_days',
    definitionVersion: version,
    visibility: AchievementVisibility.hidden,
    allowsHistoricalBackfill: false,
  );
  static const AchievementDefinition rhythm30Days = AchievementDefinition(
    id: 'rhythm_30_days',
    definitionVersion: version,
    visibility: AchievementVisibility.hidden,
    allowsHistoricalBackfill: false,
  );
  static const AchievementDefinition goldenWeek = AchievementDefinition(
    id: 'golden_week',
    definitionVersion: version,
    visibility: AchievementVisibility.hidden,
    allowsHistoricalBackfill: false,
  );

  static const List<AchievementDefinition> all = <AchievementDefinition>[
    firstReliableAnalysis,
    reliableSessions5,
    exerciseExplorer3,
    guideCompleted,
    controlledTempo,
    plannedWorkoutCompleted,
    plannedWorkouts5,
    balancedExplorer,
    returnAfter14Days,
    rhythm30Days,
    goldenWeek,
  ];

  static List<AchievementDefinition> get visible => all
      .where((item) => item.visibility == AchievementVisibility.visible)
      .toList(growable: false);

  AchievementDefinition byId(String id) {
    return all.singleWhere(
      (definition) => definition.id == id,
      orElse: () => throw ArgumentError.value(id, 'id', 'Unknown achievement'),
    );
  }
}
