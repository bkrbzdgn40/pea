import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/exercise_type.dart';

final recentExercisesProvider =
    AsyncNotifierProvider<RecentExercisesController, List<ExerciseType>>(
      RecentExercisesController.new,
    );

class RecentExercisesController extends AsyncNotifier<List<ExerciseType>> {
  static const preferenceKey = 'exerciseSelection.recentExerciseIds';
  static const maxRecentExercises = 4;

  Future<List<ExerciseType>>? _initialLoad;

  @override
  Future<List<ExerciseType>> build() {
    final load = _loadSafely();
    _initialLoad = load;
    return load;
  }

  Future<void> record(ExerciseType exercise) async {
    final current = state.valueOrNull ?? await (_initialLoad ?? _loadSafely());
    final updated = <ExerciseType>[
      exercise,
      ...current.where((item) => item != exercise),
    ].take(maxRecentExercises).toList(growable: false);

    state = AsyncData(updated);

    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setStringList(
        preferenceKey,
        updated.map((item) => item.id).toList(growable: false),
      );
    } catch (_) {
      // Recent exercises are a convenience feature. Navigation must continue
      // even when local preference persistence is unavailable.
    }
  }

  Future<List<ExerciseType>> _loadSafely() async {
    try {
      return await _load();
    } catch (_) {
      return const <ExerciseType>[];
    }
  }

  Future<List<ExerciseType>> _load() async {
    final preferences = await SharedPreferences.getInstance();
    final ids = preferences.getStringList(preferenceKey) ?? const <String>[];
    final exercises = <ExerciseType>[];

    for (final id in ids) {
      final exercise = ExerciseType.fromIdOrNull(id);
      if (exercise != null && !exercises.contains(exercise)) {
        exercises.add(exercise);
      }
      if (exercises.length == maxRecentExercises) {
        break;
      }
    }

    return List<ExerciseType>.unmodifiable(exercises);
  }
}
