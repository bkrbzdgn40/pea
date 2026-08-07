import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/goals/domain/models/user_workout_goal.dart';
import 'package:pose_estimation_app/features/goals/infrastructure/repositories/firestore_workout_goal_repository.dart';

void main() {
  test('activating a goal pauses the previous active goal', () async {
    final firestore = FakeFirebaseFirestore();
    final repository = FirestoreWorkoutGoalRepository(firestore);
    final firstTime = DateTime.utc(2026, 8, 5, 8);
    final secondTime = DateTime.utc(2026, 8, 5, 9);

    await repository.activateGoal(
      ownerId: 'user-1',
      type: WorkoutGoalType.weeklySessions,
      targetValue: 4,
      now: firstTime,
    );
    await repository.activateGoal(
      ownerId: 'user-1',
      type: WorkoutGoalType.weeklyReps,
      targetValue: 120,
      now: secondTime,
    );

    final goals = await repository.listGoals(ownerId: 'user-1');
    final sessionsGoal = goals.singleWhere(
      (goal) => goal.type == WorkoutGoalType.weeklySessions,
    );
    final repsGoal = goals.singleWhere(
      (goal) => goal.type == WorkoutGoalType.weeklyReps,
    );

    expect(sessionsGoal.status, WorkoutGoalStatus.paused);
    expect(repsGoal.status, WorkoutGoalStatus.active);
    expect(goals.where((goal) => goal.isActive), hasLength(1));
  });

  test(
    'editing the same type preserves createdAt and updates target',
    () async {
      final firestore = FakeFirebaseFirestore();
      final repository = FirestoreWorkoutGoalRepository(firestore);
      final firstTime = DateTime.utc(2026, 8, 5, 8);
      final secondTime = DateTime.utc(2026, 8, 6, 8);

      await repository.activateGoal(
        ownerId: 'user-1',
        type: WorkoutGoalType.averageScore,
        targetValue: 80,
        now: firstTime,
      );
      await repository.activateGoal(
        ownerId: 'user-1',
        type: WorkoutGoalType.averageScore,
        targetValue: 88,
        now: secondTime,
      );

      final goal = (await repository.listGoals(ownerId: 'user-1')).single;

      expect(goal.targetValue, 88);
      expect(goal.createdAt.toUtc(), firstTime);
      expect(goal.updatedAt.toUtc(), secondTime);
      expect(goal.status, WorkoutGoalStatus.active);
    },
  );

  test('pauses an active goal without deleting it', () async {
    final firestore = FakeFirebaseFirestore();
    final repository = FirestoreWorkoutGoalRepository(firestore);

    await repository.activateGoal(
      ownerId: 'user-1',
      type: WorkoutGoalType.weeklySessions,
      targetValue: 5,
      now: DateTime.utc(2026, 8, 5, 8),
    );
    await repository.pauseGoal(
      ownerId: 'user-1',
      type: WorkoutGoalType.weeklySessions,
      now: DateTime.utc(2026, 8, 5, 9),
    );

    final goal = (await repository.listGoals(ownerId: 'user-1')).single;
    expect(goal.status, WorkoutGoalStatus.paused);
  });

  test('deletes every saved goal for the owner', () async {
    final firestore = FakeFirebaseFirestore();
    final repository = FirestoreWorkoutGoalRepository(firestore);

    await repository.activateGoal(
      ownerId: 'user-1',
      type: WorkoutGoalType.weeklySessions,
      targetValue: 5,
      now: DateTime.utc(2026, 8, 5, 8),
    );
    await repository.activateGoal(
      ownerId: 'user-1',
      type: WorkoutGoalType.weeklyReps,
      targetValue: 150,
      now: DateTime.utc(2026, 8, 5, 9),
    );
    await repository.activateGoal(
      ownerId: 'user-2',
      type: WorkoutGoalType.averageScore,
      targetValue: 80,
      now: DateTime.utc(2026, 8, 5, 10),
    );

    await repository.deleteAllGoals(ownerId: 'user-1');

    expect(await repository.listGoals(ownerId: 'user-1'), isEmpty);
    expect(await repository.listGoals(ownerId: 'user-2'), hasLength(1));
  });
}
