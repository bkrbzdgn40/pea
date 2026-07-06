import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/exercise_config_resolver.dart';
import '../../domain/models/exercise_config.dart';
import '../../infrastructure/config/asset_exercise_config_source.dart';
import 'active_analysis_exercise_provider.dart';

final exerciseConfigSourceProvider = Provider<ExerciseConfigSource>((ref) {
  return const AssetExerciseConfigSource();
});

final exerciseConfigProvider = FutureProvider<ExerciseConfig>((ref) async {
  final activeExercise = ref.watch(activeAnalysisExerciseProvider);
  final source = ref.watch(exerciseConfigSourceProvider);
  final resolver = ExerciseConfigResolver(source: source);

  return resolver.resolve(activeExercise);
});
