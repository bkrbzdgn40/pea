import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/exercise_analysis_resolver.dart';
import '../../domain/models/exercise_type.dart';
import 'selected_exercise_provider.dart';

/// Adapts the current user selection into the exercise the analysis can run.
final activeAnalysisExerciseProvider = Provider<ExerciseType>((ref) {
  final selectedExercise = ref.watch(selectedExerciseProvider);
  const resolver = ExerciseAnalysisResolver();

  return resolver.resolveActiveExercise(selectedExercise);
});
