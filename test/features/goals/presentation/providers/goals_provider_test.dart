import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:pose_estimation_app/features/goals/application/repositories/workout_goal_repository.dart';
import 'package:pose_estimation_app/features/goals/domain/models/user_workout_goal.dart';
import 'package:pose_estimation_app/features/goals/presentation/providers/goals_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/session_measurement_evidence.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/user_sessions_snapshot_provider.dart';

import '../../../../support/workout_statistics_test_support.dart';

void main() {
  test('no saved goal exposes suggestions without assigning one', () async {
    final repository = _MemoryGoalRepository();
    final container = ProviderContainer(
      overrides: [
        currentUserIdProvider.overrideWithValue('user-1'),
        workoutGoalRepositoryProvider.overrideWithValue(repository),
        userSessionsSnapshotProvider.overrideWith(
          (ref) async => const UserSessionsSnapshot(
            sessions: [],
            source: UserSessionsSnapshotSource.empty,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final state = await container.read(goalsProvider.future);

    expect(state.source, GoalsDataSource.empty);
    expect(state.goals, isEmpty);
    expect(state.activeGoal, isNull);
    expect(state.templates, hasLength(3));
  });

  test('saved goals use trusted session statistics for progress', () async {
    final now = DateTime.now();
    final weekStart = startOfCurrentWeek(now);
    final repository = _MemoryGoalRepository(
      goals: [
        UserWorkoutGoal(
          id: 'weeklySessions',
          ownerId: 'user-1',
          type: WorkoutGoalType.weeklySessions,
          period: WorkoutGoalPeriod.weekly,
          targetValue: 4,
          status: WorkoutGoalStatus.active,
          createdAt: now,
          updatedAt: now,
        ),
        UserWorkoutGoal(
          id: 'weeklyReps',
          ownerId: 'user-1',
          type: WorkoutGoalType.weeklyReps,
          period: WorkoutGoalPeriod.weekly,
          targetValue: 200,
          status: WorkoutGoalStatus.paused,
          createdAt: now,
          updatedAt: now,
        ),
      ],
    );
    final container = ProviderContainer(
      overrides: [
        currentUserIdProvider.overrideWithValue('user-1'),
        workoutGoalRepositoryProvider.overrideWithValue(repository),
        userSessionsSnapshotProvider.overrideWith(
          (ref) async => UserSessionsSnapshot(
            sessions: [
              buildWorkoutSession(
                id: 'trusted',
                startedAt: weekStart,
                totalReps: 20,
                averageScore: 80,
                preparationOutcome: PreparationOutcome.passed,
                measurementQuality: SessionMeasurementQuality.high,
                averageMeasurementConfidence: 0.94,
                measurementSampleCount: 20,
              ),
              buildWorkoutSession(
                id: 'limited',
                startedAt: weekStart.add(const Duration(days: 1)),
                totalReps: 200,
                averageScore: 100,
                preparationOutcome: PreparationOutcome.passed,
                measurementQuality: SessionMeasurementQuality.limited,
                averageMeasurementConfidence: 0.7,
                measurementSampleCount: 200,
              ),
            ],
            source: UserSessionsSnapshotSource.real,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final state = await container.read(goalsProvider.future);

    expect(state.source, GoalsDataSource.real);
    expect(state.activeGoal?.currentValue, 2);
    expect(state.pausedGoals.single.currentValue, 20);
  });

  test(
    'activating a goal pauses the previous goal and refreshes state',
    () async {
      final now = DateTime.utc(2026, 8, 5, 12);
      final repository = _MemoryGoalRepository(
        goals: [
          UserWorkoutGoal(
            id: 'weeklySessions',
            ownerId: 'user-1',
            type: WorkoutGoalType.weeklySessions,
            period: WorkoutGoalPeriod.weekly,
            targetValue: 5,
            status: WorkoutGoalStatus.active,
            createdAt: now,
            updatedAt: now,
          ),
        ],
      );
      final container = ProviderContainer(
        overrides: [
          currentUserIdProvider.overrideWithValue('user-1'),
          workoutGoalRepositoryProvider.overrideWithValue(repository),
          goalsClockProvider.overrideWithValue(() => now),
          userSessionsSnapshotProvider.overrideWith(
            (ref) async => const UserSessionsSnapshot(
              sessions: [],
              source: UserSessionsSnapshotSource.empty,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(goalsProvider.future);
      final success = await container
          .read(goalManagementControllerProvider.notifier)
          .activateGoal(type: WorkoutGoalType.weeklyReps, targetValue: 150);
      final refreshed = await container.read(goalsProvider.future);

      expect(success, isTrue);
      expect(refreshed.activeGoal?.type, WorkoutGoalType.weeklyReps);
      expect(refreshed.activeGoal?.targetValue, 150);
      expect(refreshed.pausedGoals.single.type, WorkoutGoalType.weeklySessions);
    },
  );

  test('rejects an invalid user target before writing', () async {
    final repository = _MemoryGoalRepository();
    final container = ProviderContainer(
      overrides: [
        currentUserIdProvider.overrideWithValue('user-1'),
        workoutGoalRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    final success = await container
        .read(goalManagementControllerProvider.notifier)
        .activateGoal(type: WorkoutGoalType.weeklySessions, targetValue: 2.5);

    expect(success, isFalse);
    expect(repository.writeCount, 0);
    expect(
      container.read(goalManagementControllerProvider).error,
      GoalManagementError.invalidTarget,
    );
  });
}

class _MemoryGoalRepository implements WorkoutGoalRepository {
  _MemoryGoalRepository({List<UserWorkoutGoal> goals = const []})
    : _goals = List<UserWorkoutGoal>.from(goals);

  final List<UserWorkoutGoal> _goals;
  int writeCount = 0;

  @override
  Future<List<UserWorkoutGoal>> listGoals({required String ownerId}) async {
    return _goals.where((goal) => goal.ownerId == ownerId).toList();
  }

  @override
  Future<void> activateGoal({
    required String ownerId,
    required WorkoutGoalType type,
    required double targetValue,
    required DateTime now,
  }) async {
    writeCount += 1;
    for (var index = 0; index < _goals.length; index++) {
      final goal = _goals[index];
      if (goal.ownerId == ownerId && goal.isActive) {
        _goals[index] = goal.copyWith(
          status: WorkoutGoalStatus.paused,
          updatedAt: now,
        );
      }
    }

    final existingIndex = _goals.indexWhere(
      (goal) => goal.ownerId == ownerId && goal.type == type,
    );
    final existing = existingIndex == -1 ? null : _goals[existingIndex];
    final updated = UserWorkoutGoal(
      id: type.storageValue,
      ownerId: ownerId,
      type: type,
      period: type.period,
      targetValue: targetValue,
      status: WorkoutGoalStatus.active,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    if (existingIndex == -1) {
      _goals.add(updated);
    } else {
      _goals[existingIndex] = updated;
    }
  }

  @override
  Future<void> deleteAllGoals({required String ownerId}) async {
    _goals.removeWhere((goal) => goal.ownerId == ownerId);
  }

  @override
  Future<void> pauseGoal({
    required String ownerId,
    required WorkoutGoalType type,
    required DateTime now,
  }) async {
    writeCount += 1;
    final index = _goals.indexWhere(
      (goal) => goal.ownerId == ownerId && goal.type == type,
    );
    if (index == -1) return;
    _goals[index] = _goals[index].copyWith(
      status: WorkoutGoalStatus.paused,
      updatedAt: now,
    );
  }
}
