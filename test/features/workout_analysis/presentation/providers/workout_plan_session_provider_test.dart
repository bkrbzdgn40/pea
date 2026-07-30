import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/workout_engine.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/workout_state.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_type.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/selected_exercise_provider.dart';
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

  test('rebases the next same-exercise set after rest movement', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(workoutPlanSessionProvider.notifier);

    controller.start(
      WorkoutPlan(
        exercises: const [
          WorkoutExerciseBlock(
            exercise: ExerciseType.squat,
            target: WorkoutTarget.repetitions(2),
            sets: 2,
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

    controller.advance(
      resumeState: const WorkoutState.rangeRep(
        analysis: RangeRepWorkoutAnalysisState(repCount: 5),
      ),
    );
    controller.observe(
      exercise: ExerciseType.squat,
      workoutState: const WorkoutState.rangeRep(
        analysis: RangeRepWorkoutAnalysisState(repCount: 5),
      ),
    );
    expect(
      container.read(workoutPlanSessionProvider).snapshot!.currentRepetitions,
      0,
    );

    controller.observe(
      exercise: ExerciseType.squat,
      workoutState: const WorkoutState.rangeRep(
        analysis: RangeRepWorkoutAnalysisState(repCount: 6),
      ),
    );
    expect(
      container.read(workoutPlanSessionProvider).snapshot!.currentRepetitions,
      1,
    );
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

  test('does not publish plan state when repetition progress is unchanged', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(workoutPlanSessionProvider.notifier);
    var notifications = 0;
    final subscription = container.listen<WorkoutPlanSessionState>(
      workoutPlanSessionProvider,
      (previous, next) => notifications += 1,
    );
    addTearDown(subscription.close);

    controller.start(
      WorkoutPlan(
        exercises: const [
          WorkoutExerciseBlock(
            exercise: ExerciseType.squat,
            target: WorkoutTarget.repetitions(3),
          ),
        ],
      ),
    );
    notifications = 0;

    final initial = container.read(workoutPlanSessionProvider).snapshot!;
    final unchanged = controller.observe(
      exercise: ExerciseType.squat,
      workoutState: const WorkoutState.rangeRep(
        analysis: RangeRepWorkoutAnalysisState(repCount: 0),
      ),
    );

    expect(unchanged, same(initial));
    expect(notifications, 0);

    controller.observe(
      exercise: ExerciseType.squat,
      workoutState: const WorkoutState.rangeRep(
        analysis: RangeRepWorkoutAnalysisState(repCount: 1),
      ),
    );
    expect(notifications, 1);

    notifications = 0;
    final progressed = container.read(workoutPlanSessionProvider).snapshot!;
    final repeated = controller.observe(
      exercise: ExerciseType.squat,
      workoutState: const WorkoutState.rangeRep(
        analysis: RangeRepWorkoutAnalysisState(repCount: 1),
      ),
    );

    expect(repeated, same(progressed));
    expect(notifications, 0);
  });

  test('limits hold progress publications to four updates per second', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(workoutPlanSessionProvider.notifier);
    var notifications = 0;
    final subscription = container.listen<WorkoutPlanSessionState>(
      workoutPlanSessionProvider,
      (previous, next) => notifications += 1,
    );
    addTearDown(subscription.close);

    controller.start(
      WorkoutPlan(
        exercises: const [
          WorkoutExerciseBlock(
            exercise: ExerciseType.plank,
            target: WorkoutTarget.hold(Duration(seconds: 2)),
          ),
        ],
      ),
    );
    notifications = 0;

    final initial = container.read(workoutPlanSessionProvider).snapshot!;
    final early = controller.observe(
      exercise: ExerciseType.plank,
      workoutState: const WorkoutState.hold(
        analysis: HoldWorkoutAnalysisState(currentHoldSeconds: 0.1),
      ),
    );
    expect(early, same(initial));
    expect(notifications, 0);

    controller.observe(
      exercise: ExerciseType.plank,
      workoutState: const WorkoutState.hold(
        analysis: HoldWorkoutAnalysisState(currentHoldSeconds: 0.3),
      ),
    );
    expect(notifications, 1);

    notifications = 0;
    final firstBucket = container.read(workoutPlanSessionProvider).snapshot!;
    final sameBucket = controller.observe(
      exercise: ExerciseType.plank,
      workoutState: const WorkoutState.hold(
        analysis: HoldWorkoutAnalysisState(currentHoldSeconds: 0.4),
      ),
    );
    expect(sameBucket, same(firstBucket));
    expect(notifications, 0);

    controller.observe(
      exercise: ExerciseType.plank,
      workoutState: const WorkoutState.hold(
        analysis: HoldWorkoutAnalysisState(currentHoldSeconds: 0.5),
      ),
    );
    expect(notifications, 1);
  });

  test('forwards a hold timer decrease inside the same time bucket', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(workoutPlanSessionProvider.notifier);

    controller.start(
      WorkoutPlan(
        exercises: const [
          WorkoutExerciseBlock(
            exercise: ExerciseType.plank,
            target: WorkoutTarget.hold(Duration(seconds: 2)),
          ),
        ],
      ),
    );
    controller.observe(
      exercise: ExerciseType.plank,
      workoutState: const WorkoutState.hold(
        analysis: HoldWorkoutAnalysisState(currentHoldSeconds: 0.4),
      ),
    );
    final beforeDecrease = container.read(workoutPlanSessionProvider).snapshot!;

    final decreased = controller.observe(
      exercise: ExerciseType.plank,
      workoutState: const WorkoutState.hold(
        analysis: HoldWorkoutAnalysisState(currentHoldSeconds: 0.3),
      ),
    );

    expect(decreased, isNot(same(beforeDecrease)));
    expect(decreased!.currentHoldDuration, const Duration(milliseconds: 300));
  });

  test(
    'forwards an exact hold target crossing inside the same time bucket',
    () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(workoutPlanSessionProvider.notifier);

      controller.start(
        WorkoutPlan(
          exercises: const [
            WorkoutExerciseBlock(
              exercise: ExerciseType.plank,
              target: WorkoutTarget.hold(Duration(milliseconds: 1100)),
            ),
          ],
        ),
      );
      controller.observe(
        exercise: ExerciseType.plank,
        workoutState: const WorkoutState.hold(
          analysis: HoldWorkoutAnalysisState(currentHoldSeconds: 1),
        ),
      );

      final completed = controller.observe(
        exercise: ExerciseType.plank,
        workoutState: const WorkoutState.hold(
          analysis: HoldWorkoutAnalysisState(currentHoldSeconds: 1.1),
        ),
      );

      expect(completed!.isSetCompleted, isTrue);
      expect(completed.currentHoldDuration, const Duration(milliseconds: 1100));
    },
  );

  test('keeps the semantic gate across another set of the same exercise', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(workoutPlanSessionProvider.notifier);
    var notifications = 0;
    final subscription = container.listen<WorkoutPlanSessionState>(
      workoutPlanSessionProvider,
      (previous, next) => notifications += 1,
    );
    addTearDown(subscription.close);

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
    controller.advance();
    notifications = 0;

    final nextSet = container.read(workoutPlanSessionProvider).snapshot!;
    final duplicate = controller.observe(
      exercise: ExerciseType.squat,
      workoutState: const WorkoutState.rangeRep(
        analysis: RangeRepWorkoutAnalysisState(repCount: 1),
      ),
    );

    expect(duplicate, same(nextSet));
    expect(notifications, 0);

    final completed = controller.observe(
      exercise: ExerciseType.squat,
      workoutState: const WorkoutState.rangeRep(
        analysis: RangeRepWorkoutAnalysisState(repCount: 2),
      ),
    );
    expect(completed!.isSetCompleted, isTrue);
    expect(completed.currentRepetitions, 1);
  });

  test('restores the explicit exercise selection after a plan ends', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(workoutPlanSessionProvider.notifier);

    container.read(selectedExerciseProvider.notifier).state =
        ExerciseType.pushUp;
    controller.start(
      WorkoutPlan(
        exercises: const [
          WorkoutExerciseBlock(
            exercise: ExerciseType.squat,
            target: WorkoutTarget.repetitions(10),
          ),
        ],
      ),
      selectedExerciseBeforePlan: container.read(selectedExerciseProvider),
      restoreSelectedExerciseOnReset: true,
    );
    container.read(selectedExerciseProvider.notifier).state =
        ExerciseType.squat;

    controller.reset();

    expect(container.read(workoutPlanSessionProvider).hasPlan, isFalse);
    expect(container.read(selectedExerciseProvider), ExerciseType.pushUp);
  });

  test('clears the plan exercise when no explicit selection existed', () {
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
      selectedExerciseBeforePlan: container.read(selectedExerciseProvider),
      restoreSelectedExerciseOnReset: true,
    );
    container.read(selectedExerciseProvider.notifier).state =
        ExerciseType.squat;

    controller.reset();

    expect(container.read(selectedExerciseProvider), isNull);
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
