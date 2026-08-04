import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/exercise_analysis_resolver.dart';
import '../../application/exercise_catalog.dart';
import '../../domain/models/exercise_type.dart';
import 'selected_exercise_provider.dart';

/// Adapts the current user selection into the exercise the analysis can run.
final activeAnalysisExerciseProvider = Provider<ExerciseType?>((ref) {
  final selectedExercise = ref.watch(selectedExerciseProvider);
  const resolver = ExerciseAnalysisResolver();

  return resolver.resolveActiveExercise(selectedExercise);
});

/// Analysis cadence shared by the frame pipeline and camera backpressure gate.
final activeAnalysisFrameIntervalProvider = Provider<Duration>((ref) {
  final activeExercise = ref.watch(activeAnalysisExerciseProvider);
  if (activeExercise == null) {
    return const Duration(milliseconds: 100);
  }
  return const ExerciseCatalog()
      .definitionFor(activeExercise)
      .analysisFrameInterval;
});
