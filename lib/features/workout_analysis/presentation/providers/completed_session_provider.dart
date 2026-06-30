import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/workout_session.dart';

final completedSessionProvider = StateProvider<WorkoutSession?>((ref) {
  return null;
});
