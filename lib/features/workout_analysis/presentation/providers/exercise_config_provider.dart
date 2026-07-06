import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/exercise_config.dart';
import '../../domain/models/exercise_type.dart';
import 'active_analysis_exercise_provider.dart';

final exerciseConfigProvider = Provider<ExerciseConfig>((ref) {
  final activeExercise = ref.watch(activeAnalysisExerciseProvider);

  return switch (activeExercise) {
    ExerciseType.squat => ExerciseConfig.squat(),
    _ => ExerciseConfig.squat(),
  };
});
