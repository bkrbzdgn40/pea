import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/app/presentation/widgets/app_drawer.dart';
import 'package:pose_estimation_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:pose_estimation_app/features/goals/application/repositories/workout_goal_repository.dart';
import 'package:pose_estimation_app/features/goals/domain/models/user_workout_goal.dart';
import 'package:pose_estimation_app/features/goals/presentation/models/workout_goal.dart';
import 'package:pose_estimation_app/features/goals/presentation/providers/goals_provider.dart';
import 'package:pose_estimation_app/features/goals/presentation/screens/goals_screen.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/user_sessions_snapshot_provider.dart';

import '../../../../support/presentation_test_harness.dart';
import '../../../../support/presentation_test_support.dart';

void main() {
  testWidgets('shows the shared loading state while goals are unresolved', (
    WidgetTester tester,
  ) async {
    final completer = Completer<GoalsState>();

    await pumpTestApp(
      tester,
      home: const GoalsScreen(),
      overrides: [goalsProvider.overrideWith((ref) => completer.future)],
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    completer.complete(
      const GoalsState(source: GoalsDataSource.empty, goals: <WorkoutGoal>[]),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Hedef önerileri'), findsOneWidget);
  });

  testWidgets('exposes Goals as the selected drawer destination', (
    WidgetTester tester,
  ) async {
    await pumpTestApp(
      tester,
      home: const GoalsScreen(),
      overrides: [
        goalsProvider.overrideWith(
          (ref) => const GoalsState(
            source: GoalsDataSource.empty,
            goals: <WorkoutGoal>[],
          ),
        ),
      ],
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.menu).first);
    await tester.pumpAndSettle();

    final drawerScrollable = find.descendant(
      of: find.byType(Drawer),
      matching: find.byType(Scrollable),
    );
    final goalsTile = find.widgetWithText(ListTile, 'Hedefler');
    await tester.scrollUntilVisible(
      goalsTile,
      180,
      scrollable: drawerScrollable,
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppDrawer), findsOneWidget);
    expect(tester.widget<ListTile>(goalsTile).selected, isTrue);
  });

  testWidgets('shows one active goal and keeps paused goals secondary', (
    WidgetTester tester,
  ) async {
    await pumpTestApp(
      tester,
      home: const GoalsScreen(),
      overrides: [
        goalsProvider.overrideWith(
          (ref) => const GoalsState(
            source: GoalsDataSource.real,
            goals: [
              WorkoutGoal(
                id: 'weeklySessions',
                title: '',
                targetValue: 4,
                currentValue: 2,
                unit: '',
                description: '',
                isCompleted: false,
                type: WorkoutGoalType.weeklySessions,
              ),
              WorkoutGoal(
                id: 'weeklyReps',
                title: '',
                targetValue: 150,
                currentValue: 50,
                unit: '',
                description: '',
                isCompleted: false,
                type: WorkoutGoalType.weeklyReps,
                status: WorkoutGoalStatus.paused,
              ),
            ],
          ),
        ),
      ],
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('active-goal-card')), findsOneWidget);
    expect(find.text('Haftada 4 analiz'), findsOneWidget);
    expect(find.text('Düzenle'), findsWidgets);
    expect(find.text('Duraklat'), findsOneWidget);

    final verticalScrollable = find.byWidgetPredicate(
      (widget) =>
          widget is Scrollable && widget.axisDirection == AxisDirection.down,
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('paused-goal-weeklyReps')),
      180,
      scrollable: verticalScrollable,
    );

    expect(find.text('Duraklatılan hedefler'), findsOneWidget);
    expect(find.text('Haftada 150 tekrar'), findsOneWidget);
  });

  testWidgets('lets the user choose a custom target from a suggestion', (
    WidgetTester tester,
  ) async {
    final repository = _MemoryGoalRepository();

    await pumpTestApp(
      tester,
      home: const GoalsScreen(),
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
    await tester.pumpAndSettle();

    final template = find.byKey(const ValueKey('goal-template-weeklySessions'));
    await tester.tap(
      find.descendant(of: template, matching: find.text('Başlat')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('goal-target-field')), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('goal-target-field')),
      '7',
    );
    await tester.tap(find.text('Başlat').last);
    await tester.pumpAndSettle();

    expect(repository.goals.single.targetValue, 7);
    expect(repository.goals.single.status, WorkoutGoalStatus.active);
    expect(find.text('Haftada 7 analiz'), findsOneWidget);
  });

  testWidgets('remains usable on a compact viewport with large text', (
    WidgetTester tester,
  ) async {
    await pumpTestApp(
      tester,
      home: const GoalsScreen(),
      configuration: const PresentationTestConfiguration(
        viewport: PresentationTestViewport.compactPortrait,
        textScaleFactor: 2,
      ),
      overrides: [
        goalsProvider.overrideWith(
          (ref) => const GoalsState(source: GoalsDataSource.empty, goals: []),
        ),
      ],
    );
    await tester.pump();

    final verticalScrollable = find.byWidgetPredicate(
      (widget) =>
          widget is Scrollable && widget.axisDirection == AxisDirection.down,
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('goal-template-averageScore')),
      180,
      scrollable: verticalScrollable,
    );

    expect(
      find.byKey(const ValueKey('goal-template-averageScore')),
      findsOneWidget,
    );
    expectNoPresentationExceptions(tester);
  });

  testWidgets('rejects fractional session targets in the editor', (
    WidgetTester tester,
  ) async {
    await pumpTestApp(
      tester,
      home: const GoalsScreen(),
      overrides: [
        goalsProvider.overrideWith(
          (ref) => const GoalsState(source: GoalsDataSource.empty, goals: []),
        ),
      ],
    );
    await tester.pump();

    final template = find.byKey(const ValueKey('goal-template-weeklySessions'));
    await tester.tap(
      find.descendant(of: template, matching: find.text('Başlat')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('goal-target-field')),
      '2.5',
    );
    await tester.tap(find.text('Başlat').last);
    await tester.pump();

    expect(
      find.text('Bu hedef için geçerli aralıkta bir değer gir.'),
      findsOneWidget,
    );
  });
}

class _MemoryGoalRepository implements WorkoutGoalRepository {
  final List<UserWorkoutGoal> goals = [];

  @override
  Future<List<UserWorkoutGoal>> listGoals({required String ownerId}) async {
    return List<UserWorkoutGoal>.from(goals);
  }

  @override
  Future<void> activateGoal({
    required String ownerId,
    required WorkoutGoalType type,
    required double targetValue,
    required DateTime now,
  }) async {
    for (var index = 0; index < goals.length; index++) {
      if (goals[index].isActive) {
        goals[index] = goals[index].copyWith(
          status: WorkoutGoalStatus.paused,
          updatedAt: now,
        );
      }
    }
    final existingIndex = goals.indexWhere((goal) => goal.type == type);
    final existing = existingIndex == -1 ? null : goals[existingIndex];
    final goal = UserWorkoutGoal(
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
      goals.add(goal);
    } else {
      goals[existingIndex] = goal;
    }
  }

  @override
  Future<void> deleteAllGoals({required String ownerId}) async {
    goals.removeWhere((goal) => goal.ownerId == ownerId);
  }

  @override
  Future<void> pauseGoal({
    required String ownerId,
    required WorkoutGoalType type,
    required DateTime now,
  }) async {
    final index = goals.indexWhere((goal) => goal.type == type);
    if (index == -1) return;
    goals[index] = goals[index].copyWith(
      status: WorkoutGoalStatus.paused,
      updatedAt: now,
    );
  }
}
