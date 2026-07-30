import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/saved_workout_plan.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/workout_engine.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_type.dart';
import 'package:pose_estimation_app/features/workout_analysis/infrastructure/local/shared_preferences_workout_plan_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('saves, updates, orders, and deletes plans locally', () async {
    const repository = SharedPreferencesWorkoutPlanRepository();
    final older = _plan(
      id: 'older',
      name: 'Eski',
      updatedAt: DateTime.utc(2026, 7, 29),
    );
    final newer = _plan(
      id: 'newer',
      name: 'Yeni',
      updatedAt: DateTime.utc(2026, 7, 30),
    );

    await repository.savePlan(older);
    await repository.savePlan(newer);

    var plans = await repository.loadPlans();
    expect(plans.map((plan) => plan.id), ['newer', 'older']);

    await repository.savePlan(
      older.copyWith(name: 'Güncellenen', updatedAt: DateTime.utc(2026, 7, 31)),
    );
    plans = await repository.loadPlans();
    expect(plans.map((plan) => plan.id), ['older', 'newer']);
    expect(plans.first.name, 'Güncellenen');

    await repository.deletePlan('older');
    plans = await repository.loadPlans();
    expect(plans.map((plan) => plan.id), ['newer']);
  });
}

SavedWorkoutPlan _plan({
  required String id,
  required String name,
  required DateTime updatedAt,
}) {
  return SavedWorkoutPlan(
    id: id,
    name: name,
    rounds: 1,
    updatedAt: updatedAt,
    entries: const [
      SavedWorkoutPlanEntry(
        id: 'entry',
        exercise: ExerciseType.squat,
        sets: 1,
        target: WorkoutTarget.repetitions(10),
        restAfterSet: Duration(seconds: 30),
      ),
    ],
  );
}
