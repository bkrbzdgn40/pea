import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/workout_engine.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/workout_state.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_type.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/workout_plan_session_provider.dart';

void main() {
  test('feeds live repetition progress into the active workout plan', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(workoutPlanSessionProvider.notifier);

    controller.start(
      WorkoutPlan(
        exercises: const [
          WorkoutExerciseBlock(
            exercise: ExerciseType.squat,
            target: WorkoutTarget.repetitions(2),
          ),
        ],
      ),
    );

    controller.observe(
      exercise: ExerciseType.squat,
      workoutState: const WorkoutState.rangeRep(
        analysis: RangeRepWorkoutAnalysisState(repCount: 2),
      ),
    );

    final snapshot = container.read(workoutPlanSessionProvider).snapshot!;
    expect(snapshot.isSetCompleted, isTrue);
    expect(snapshot.currentRepetitions, 2);
  });

  test('keeps explicit advance semantics for another set of same exercise', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(workoutPlanSessionProvider.notifier);

    controller.start(
      WorkoutPlan(
        exercises: const [
          WorkoutExerciseBlock(
            exercise: ExerciseType.squat,
            target: WorkoutTarget.repetitions(1),
            sets: 2,
          ),
        ],
      ),
    );
    controller.observe(
      exercise: ExerciseType.squat,
      workoutState: const WorkoutState.rangeRep(
        analysis: RangeRepWorkoutAnalysisState(repCount: 1),
      ),
    );

    expect(controller.nextExerciseAfterCompletedSet, ExerciseType.squat);
    final next = controller.advance();
    expect(next.isActive, isTrue);
    expect(next.setNumber, 2);
  });

  test('exposes the next exercise and completes a mixed rep-hold plan', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(workoutPlanSessionProvider.notifier);

    controller.start(
      WorkoutPlan(
        exercises: const [
          WorkoutExerciseBlock(
            exercise: ExerciseType.squat,
            target: WorkoutTarget.repetitions(1),
          ),
          WorkoutExerciseBlock(
            exercise: ExerciseType.plank,
            target: WorkoutTarget.hold(Duration(seconds: 2)),
          ),
        ],
      ),
    );
    controller.observe(
      exercise: ExerciseType.squat,
      workoutState: const WorkoutState.rangeRep(
        analysis: RangeRepWorkoutAnalysisState(repCount: 1),
      ),
    );

    expect(controller.nextExerciseAfterCompletedSet, ExerciseType.plank);
    controller.advance();
    controller.observe(
      exercise: ExerciseType.plank,
      workoutState: const WorkoutState.hold(
        analysis: HoldWorkoutAnalysisState(currentHoldSeconds: 2),
      ),
    );

    expect(controller.nextExerciseAfterCompletedSet, isNull);
    final completed = controller.advance();
    expect(completed.isWorkoutCompleted, isTrue);
    expect(completed.summary.completedSets, 2);
    expect(completed.summary.totalRepetitions, 1);
    expect(completed.summary.totalHoldDuration, const Duration(seconds: 2));
  });

  test('ignores stale analysis-family state while switching exercises', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(workoutPlanSessionProvider.notifier);

    controller.start(
      WorkoutPlan(
        exercises: const [
          WorkoutExerciseBlock(
            exercise: ExerciseType.squat,
            target: WorkoutTarget.repetitions(1),
          ),
          WorkoutExerciseBlock(
            exercise: ExerciseType.plank,
            target: WorkoutTarget.hold(Duration(seconds: 2)),
          ),
        ],
      ),
    );
    controller.observe(
      exercise: ExerciseType.squat,
      workoutState: const WorkoutState.rangeRep(
        analysis: RangeRepWorkoutAnalysisState(repCount: 1),
      ),
    );
    controller.advance();

    expect(
      () => controller.observe(
        exercise: ExerciseType.plank,
        workoutState: const WorkoutState.rangeRep(
          analysis: RangeRepWorkoutAnalysisState(repCount: 1),
        ),
      ),
      returnsNormally,
    );
    expect(
      container.read(workoutPlanSessionProvider).snapshot!.currentHoldDuration,
      Duration.zero,
    );
  });

  test('reset clears the active workout plan', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(workoutPlanSessionProvider.notifier);

    controller.start(
      WorkoutPlan(
        exercises: const [
          WorkoutExerciseBlock(
            exercise: ExerciseType.squat,
            target: WorkoutTarget.repetitions(10),
          ),
        ],
      ),
    );
    controller.reset();

    expect(container.read(workoutPlanSessionProvider).hasPlan, isFalse);
  });
}
