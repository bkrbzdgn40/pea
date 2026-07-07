import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/exercise_type.dart';

/// Holds the user's explicit exercise selection for entering analysis.
///
/// `null` means the user has not chosen an exercise yet.
final selectedExerciseProvider = StateProvider<ExerciseType?>((ref) {
  return null;
});
