import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/saved_workout_plan.dart';
import '../providers/selected_exercise_provider.dart';
import '../providers/workout_plan_session_provider.dart';
import '../screens/camera_permission_screen.dart';

void launchWorkoutPlan({
  required BuildContext context,
  required WidgetRef ref,
  required SavedWorkoutPlan plan,
}) {
  final selectedExerciseBeforePlan = ref.read(selectedExerciseProvider);
  final snapshot = ref
      .read(workoutPlanSessionProvider.notifier)
      .start(
        plan.toWorkoutPlan(),
        selectedExerciseBeforePlan: selectedExerciseBeforePlan,
        restoreSelectedExerciseOnReset: true,
      );
  final firstExercise = snapshot.currentExercise;
  if (firstExercise == null) {
    return;
  }

  ref.read(selectedExerciseProvider.notifier).state = firstExercise;
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const CameraPermissionScreen()),
  );
}
