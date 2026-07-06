import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/exercise_type.dart';

final selectedExerciseProvider = StateProvider<ExerciseType>((ref) {
  return ExerciseType.squat;
});
