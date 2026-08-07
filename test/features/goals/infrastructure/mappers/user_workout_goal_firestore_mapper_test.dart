import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/goals/domain/models/user_workout_goal.dart';
import 'package:pose_estimation_app/features/goals/infrastructure/mappers/user_workout_goal_firestore_mapper.dart';

void main() {
  const mapper = UserWorkoutGoalFirestoreMapper();

  test('round-trips a user workout goal document', () {
    final goal = UserWorkoutGoal(
      id: 'weeklySessions',
      ownerId: 'user-1',
      type: WorkoutGoalType.weeklySessions,
      period: WorkoutGoalPeriod.weekly,
      targetValue: 4,
      status: WorkoutGoalStatus.active,
      createdAt: DateTime.utc(2026, 8, 5, 8),
      updatedAt: DateTime.utc(2026, 8, 5, 9),
    );

    final document = mapper.toDocument(goal);
    final decoded = mapper.fromDocument(document);

    expect(document['targetValue'], isA<int>());
    expect(decoded.id, goal.id);
    expect(decoded.ownerId, goal.ownerId);
    expect(decoded.type, goal.type);
    expect(decoded.period, goal.period);
    expect(decoded.targetValue, goal.targetValue);
    expect(decoded.status, goal.status);
    expect(decoded.createdAt.toUtc(), goal.createdAt);
    expect(decoded.updatedAt.toUtc(), goal.updatedAt);
  });

  test('rejects unknown enum values', () {
    final goal = UserWorkoutGoal(
      id: 'weeklySessions',
      ownerId: 'user-1',
      type: WorkoutGoalType.weeklySessions,
      period: WorkoutGoalPeriod.weekly,
      targetValue: 4,
      status: WorkoutGoalStatus.active,
      createdAt: DateTime.utc(2026, 8, 5, 8),
      updatedAt: DateTime.utc(2026, 8, 5, 9),
    );
    final data = mapper.toDocument(goal)..['status'] = 'finished';

    expect(() => mapper.fromDocument(data), throwsFormatException);
  });

  test('rejects a document whose id and type disagree', () {
    final goal = UserWorkoutGoal(
      id: 'weeklySessions',
      ownerId: 'user-1',
      type: WorkoutGoalType.weeklySessions,
      period: WorkoutGoalPeriod.weekly,
      targetValue: 4,
      status: WorkoutGoalStatus.active,
      createdAt: DateTime.utc(2026, 8, 5, 8),
      updatedAt: DateTime.utc(2026, 8, 5, 9),
    );
    final data = mapper.toDocument(goal)..['id'] = 'weeklyReps';

    expect(() => mapper.fromDocument(data), throwsFormatException);
  });

  test('rejects an out-of-range target from malformed storage', () {
    final goal = UserWorkoutGoal(
      id: 'weeklySessions',
      ownerId: 'user-1',
      type: WorkoutGoalType.weeklySessions,
      period: WorkoutGoalPeriod.weekly,
      targetValue: 4,
      status: WorkoutGoalStatus.active,
      createdAt: DateTime.utc(2026, 8, 5, 8),
      updatedAt: DateTime.utc(2026, 8, 5, 9),
    );
    final data = mapper.toDocument(goal)..['targetValue'] = 50;

    expect(() => mapper.fromDocument(data), throwsFormatException);
  });

  test('does not silently truncate a fractional weekly target', () {
    final goal = UserWorkoutGoal(
      id: 'weeklySessions',
      ownerId: 'user-1',
      type: WorkoutGoalType.weeklySessions,
      period: WorkoutGoalPeriod.weekly,
      targetValue: 2.5,
      status: WorkoutGoalStatus.active,
      createdAt: DateTime.utc(2026, 8, 5, 8),
      updatedAt: DateTime.utc(2026, 8, 5, 9),
    );

    expect(() => mapper.toDocument(goal), throwsArgumentError);
  });
}
