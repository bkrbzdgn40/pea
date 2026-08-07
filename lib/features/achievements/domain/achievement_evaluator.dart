import 'achievement_catalog.dart';
import 'models/achievement_body_region.dart';
import 'models/achievement_definition.dart';
import 'models/achievement_evaluation.dart';
import 'models/achievement_facts.dart';

class AchievementEvaluator {
  const AchievementEvaluator();

  static const Set<String> requiredGuideStepIds = <String>{
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
  };

  List<AchievementEvaluation> evaluateAll(AchievementFacts facts) {
    return AchievementCatalog.all
        .map((definition) => evaluate(definition, facts))
        .toList(growable: false);
  }

  AchievementEvaluation evaluate(
    AchievementDefinition definition,
    AchievementFacts facts,
  ) {
    return switch (definition.id) {
      'first_reliable_analysis' => _countEvaluation(
        definition,
        current: facts.reliableSessionIds.length,
        target: 1,
        qualifyingEventId: _firstOrNull(facts.reliableSessionIds),
      ),
      'reliable_sessions_5' => _countEvaluation(
        definition,
        current: facts.reliableSessionIds.length,
        target: 5,
        qualifyingEventId: _firstOrNull(facts.reliableSessionIds),
      ),
      'exercise_explorer_3' => _countEvaluation(
        definition,
        current: facts.reliableExerciseTypes.length,
        target: 3,
      ),
      'guide_completed' => _countEvaluation(
        definition,
        current: requiredGuideStepIds
            .intersection(facts.openedGuideStepIds)
            .length,
        target: requiredGuideStepIds.length,
      ),
      'controlled_tempo' => _countEvaluation(
        definition,
        current: facts.controlledTempoSessionIds.length,
        target: 1,
        qualifyingEventId: _firstOrNull(facts.controlledTempoSessionIds),
      ),
      'planned_workout_completed' => _countEvaluation(
        definition,
        current: facts.completedPlanRunIds.length,
        target: 1,
        qualifyingEventId: _firstOrNull(facts.completedPlanRunIds),
      ),
      'planned_workouts_5' => _countEvaluation(
        definition,
        current: facts.completedPlanRunIds.length,
        target: 5,
      ),
      'balanced_explorer' => _countEvaluation(
        definition,
        current: _balancedRegionCount(facts),
        target: 3,
      ),
      'return_after_14_days' => _booleanEvaluation(
        definition,
        unlocked: _hasReturnAfter14EmptyDays(facts.qualifiedLocalDayKeys),
      ),
      'rhythm_30_days' => _countEvaluation(
        definition,
        current: _longestConsecutiveRun(facts.qualifiedLocalDayKeys),
        target: 30,
      ),
      'golden_week' => _booleanEvaluation(
        definition,
        unlocked: facts.weeklyMedalExerciseIdsByWeek.values.any(
          (exerciseTypes) => exerciseTypes.length >= 3,
        ),
      ),
      _ => throw ArgumentError.value(
        definition.id,
        'definition',
        'Unsupported achievement definition.',
      ),
    };
  }

  AchievementEvaluation _countEvaluation(
    AchievementDefinition definition, {
    required int current,
    required int target,
    String? qualifyingEventId,
  }) {
    return AchievementEvaluation(
      definition: definition,
      isUnlocked: current >= target,
      current: current.clamp(0, target).toInt(),
      target: target,
      qualifyingEventId: current >= target ? qualifyingEventId : null,
    );
  }

  AchievementEvaluation _booleanEvaluation(
    AchievementDefinition definition, {
    required bool unlocked,
  }) {
    return AchievementEvaluation(
      definition: definition,
      isUnlocked: unlocked,
      current: unlocked ? 1 : 0,
      target: 1,
    );
  }

  int _balancedRegionCount(AchievementFacts facts) {
    const required = <AchievementBodyRegion>{
      AchievementBodyRegion.lowerBody,
      AchievementBodyRegion.upperBody,
      AchievementBodyRegion.core,
    };
    return required.intersection(facts.reliableBodyRegions).length;
  }

  bool _hasReturnAfter14EmptyDays(Set<String> keys) {
    final days = _sortedUniqueDays(keys);
    for (var index = 1; index < days.length; index += 1) {
      if (days[index].difference(days[index - 1]).inDays >= 15) {
        return true;
      }
    }
    return false;
  }

  int _longestConsecutiveRun(Set<String> keys) {
    final days = _sortedUniqueDays(keys);
    if (days.isEmpty) {
      return 0;
    }
    var longest = 1;
    var current = 1;
    for (var index = 1; index < days.length; index += 1) {
      final difference = days[index].difference(days[index - 1]).inDays;
      if (difference == 1) {
        current += 1;
        if (current > longest) {
          longest = current;
        }
      } else {
        current = 1;
      }
    }
    return longest;
  }

  List<DateTime> _sortedUniqueDays(Set<String> keys) {
    final days = keys.map(_parseLocalDayKey).toSet().toList(growable: false);
    days.sort();
    return days;
  }

  DateTime _parseLocalDayKey(String key) {
    final match = RegExp(r'^\d{4}-\d{2}-\d{2}$').firstMatch(key);
    if (match == null) {
      throw FormatException('Invalid local day key: $key');
    }
    final parsed = DateTime.tryParse(key);
    if (parsed == null || _formatDay(parsed) != key) {
      throw FormatException('Invalid local day key: $key');
    }
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  String _formatDay(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }
}

String? _firstOrNull(Set<String> values) {
  if (values.isEmpty) {
    return null;
  }
  final sorted = values.toList(growable: false)..sort();
  return sorted.first;
}
