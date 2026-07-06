import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/exercise_config_resolver.dart';
import '../../domain/models/exercise_config.dart';
import 'active_analysis_exercise_provider.dart';

final exerciseConfigProvider = Provider<ExerciseConfig>((ref) {
  final activeExercise = ref.watch(activeAnalysisExerciseProvider);
  const resolver = ExerciseConfigResolver();

  return resolver.resolve(activeExercise);
});
