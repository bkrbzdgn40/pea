import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/exercise_type.dart';
import 'selected_exercise_provider.dart';

/// Resolves the movement the analysis pipeline can safely run right now.
final activeAnalysisExerciseProvider = Provider<ExerciseType>((ref) {
  final selectedExercise = ref.watch(selectedExerciseProvider);

  return switch (selectedExercise) {
    ExerciseType.squat => ExerciseType.squat,
    // Unsupported selections currently fall back to the only implemented engine.
    ExerciseType.plank ||
    ExerciseType.lunge ||
    ExerciseType.pushUp ||
    ExerciseType.sitUp => ExerciseType.squat,
  };
});
