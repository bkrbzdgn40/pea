import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/exercise_config.dart';
import '../../domain/models/exercise_type.dart';
import 'active_analysis_exercise_provider.dart';

final exerciseConfigProvider = Provider<ExerciseConfig>((ref) {
  final activeExercise = ref.watch(activeAnalysisExerciseProvider);

  if (activeExercise == ExerciseType.squat) {
    return ExerciseConfig.squat();
  }

  assert(
    false,
    'Unsupported active analysis exercise reached config resolution: '
    '$activeExercise',
  );
  return ExerciseConfig.squat();
});
