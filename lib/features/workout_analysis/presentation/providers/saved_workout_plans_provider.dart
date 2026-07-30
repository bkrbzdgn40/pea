import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/saved_workout_plan.dart';
import '../../infrastructure/local/shared_preferences_workout_plan_repository.dart';

final workoutPlanRepositoryProvider = Provider<WorkoutPlanRepository>((ref) {
  return const SharedPreferencesWorkoutPlanRepository();
});

final savedWorkoutPlansProvider =
    AsyncNotifierProvider<SavedWorkoutPlansController, List<SavedWorkoutPlan>>(
      SavedWorkoutPlansController.new,
    );

class SavedWorkoutPlansController
    extends AsyncNotifier<List<SavedWorkoutPlan>> {
  WorkoutPlanRepository get _repository =>
      ref.read(workoutPlanRepositoryProvider);

  @override
  Future<List<SavedWorkoutPlan>> build() => _repository.loadPlans();

  Future<void> save(SavedWorkoutPlan plan) async {
    await _repository.savePlan(plan);
    state = AsyncData(await _repository.loadPlans());
  }

  Future<void> delete(String planId) async {
    await _repository.deletePlan(planId);
    state = AsyncData(await _repository.loadPlans());
  }
}
