import '../domain/models/exercise_type.dart';
import 'exercise_catalog.dart';
import 'exercise_definition_metadata.dart';
import 'workout_engine.dart';

class SavedWorkoutPlanEntry {
  const SavedWorkoutPlanEntry({
    required this.id,
    required this.exercise,
    required this.sets,
    required this.target,
    required this.restAfterSet,
  });

  final String id;
  final ExerciseType exercise;
  final int sets;
  final WorkoutTarget target;
  final Duration restAfterSet;

  SavedWorkoutPlanEntry copyWith({
    String? id,
    ExerciseType? exercise,
    int? sets,
    WorkoutTarget? target,
    Duration? restAfterSet,
  }) {
    return SavedWorkoutPlanEntry(
      id: id ?? this.id,
      exercise: exercise ?? this.exercise,
      sets: sets ?? this.sets,
      target: target ?? this.target,
      restAfterSet: restAfterSet ?? this.restAfterSet,
    );
  }

  Duration get normalizedRestAfterSet => Duration(
    seconds: restAfterSet.inSeconds
        .clamp(0, maxWorkoutPlanRestDuration.inSeconds)
        .toInt(),
  );

  SavedWorkoutPlanEntry normalized() {
    final normalizedRest = normalizedRestAfterSet;
    if (normalizedRest == restAfterSet) {
      return this;
    }
    return copyWith(restAfterSet: normalizedRest);
  }

  WorkoutExerciseBlock toWorkoutBlock() {
    return WorkoutExerciseBlock(
      exercise: exercise,
      target: target,
      sets: sets,
      restAfterSet: normalizedRestAfterSet,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'exercise': exercise.id,
      'sets': sets,
      'targetType': target.type.name,
      'targetValue': target.type == WorkoutTargetType.repetitions
          ? target.repetitions
          : target.holdDuration?.inSeconds,
      'restSeconds': normalizedRestAfterSet.inSeconds,
    };
  }

  static SavedWorkoutPlanEntry? fromJson(Map<String, Object?> json) {
    final exerciseId = json['exercise'];
    final id = json['id'];
    final sets = json['sets'];
    final targetType = json['targetType'];
    final targetValue = json['targetValue'];
    final restSeconds = json['restSeconds'];
    if (exerciseId is! String ||
        id is! String ||
        sets is! num ||
        targetType is! String ||
        targetValue is! num ||
        restSeconds is! num) {
      return null;
    }

    final exercise = ExerciseType.fromIdOrNull(exerciseId);
    if (exercise == null || sets <= 0 || targetValue <= 0 || restSeconds < 0) {
      return null;
    }

    final definition = const ExerciseCatalog().definitionFor(exercise);
    final WorkoutTarget target;
    switch (targetType) {
      case 'repetitions':
        if (definition.trackingType != ExerciseTrackingType.repetitions) {
          return null;
        }
        target = WorkoutTarget.repetitions(targetValue.toInt());
        break;
      case 'holdDuration':
        if (definition.trackingType != ExerciseTrackingType.hold) {
          return null;
        }
        target = WorkoutTarget.hold(Duration(seconds: targetValue.toInt()));
        break;
      default:
        return null;
    }

    return SavedWorkoutPlanEntry(
      id: id,
      exercise: exercise,
      sets: sets.toInt(),
      target: target,
      restAfterSet: Duration(
        seconds: restSeconds
            .toInt()
            .clamp(0, maxWorkoutPlanRestDuration.inSeconds)
            .toInt(),
      ),
    );
  }
}

class SavedWorkoutPlan {
  SavedWorkoutPlan({
    required this.id,
    required this.name,
    required this.rounds,
    required List<SavedWorkoutPlanEntry> entries,
    required this.updatedAt,
  }) : entries = List<SavedWorkoutPlanEntry>.unmodifiable(
         entries.map((entry) => entry.normalized()),
       );

  final String id;
  final String name;
  final int rounds;
  final List<SavedWorkoutPlanEntry> entries;
  final DateTime updatedAt;

  SavedWorkoutPlan copyWith({
    String? id,
    String? name,
    int? rounds,
    List<SavedWorkoutPlanEntry>? entries,
    DateTime? updatedAt,
  }) {
    return SavedWorkoutPlan(
      id: id ?? this.id,
      name: name ?? this.name,
      rounds: rounds ?? this.rounds,
      entries: entries ?? this.entries,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  WorkoutPlan toWorkoutPlan() {
    return WorkoutPlan(
      id: id,
      name: name,
      rounds: rounds,
      exercises: entries
          .map((entry) => entry.toWorkoutBlock())
          .toList(growable: false),
    );
  }

  int get totalSetsPerRound =>
      entries.fold<int>(0, (total, entry) => total + entry.sets);

  int get totalSets => totalSetsPerRound * rounds;

  Duration get estimatedRestDuration {
    if (entries.isEmpty) {
      return Duration.zero;
    }

    var total = Duration.zero;
    var remainingSets = totalSets;
    for (var round = 0; round < rounds; round += 1) {
      for (final entry in entries) {
        for (var set = 0; set < entry.sets; set += 1) {
          remainingSets -= 1;
          if (remainingSets > 0) {
            total += entry.normalizedRestAfterSet;
          }
        }
      }
    }
    return total;
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'name': name,
      'rounds': rounds,
      'updatedAt': updatedAt.toIso8601String(),
      'entries': entries.map((entry) => entry.toJson()).toList(growable: false),
    };
  }

  static SavedWorkoutPlan? fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final name = json['name'];
    final rounds = json['rounds'];
    final updatedAt = json['updatedAt'];
    final rawEntries = json['entries'];
    if (id is! String ||
        name is! String ||
        rounds is! num ||
        updatedAt is! String ||
        rawEntries is! List) {
      return null;
    }

    final parsedDate = DateTime.tryParse(updatedAt);
    if (name.trim().isEmpty || rounds <= 0 || parsedDate == null) {
      return null;
    }

    final entries = <SavedWorkoutPlanEntry>[];
    for (final rawEntry in rawEntries) {
      if (rawEntry is! Map) {
        continue;
      }
      final entry = SavedWorkoutPlanEntry.fromJson(
        Map<String, Object?>.from(rawEntry),
      );
      if (entry != null) {
        entries.add(entry);
      }
    }
    if (entries.isEmpty) {
      return null;
    }

    return SavedWorkoutPlan(
      id: id,
      name: name.trim(),
      rounds: rounds.toInt(),
      entries: entries,
      updatedAt: parsedDate,
    );
  }
}

abstract interface class WorkoutPlanRepository {
  Future<List<SavedWorkoutPlan>> loadPlans();

  Future<void> savePlan(SavedWorkoutPlan plan);

  Future<void> deletePlan(String planId);
}
