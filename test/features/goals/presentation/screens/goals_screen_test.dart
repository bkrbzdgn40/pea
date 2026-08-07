import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/app/presentation/widgets/app_drawer.dart';
import 'package:pose_estimation_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:pose_estimation_app/features/challenges/domain/challenge_catalog.dart';
import 'package:pose_estimation_app/features/challenges/domain/models/challenge_period.dart';
import 'package:pose_estimation_app/features/challenges/domain/models/challenge_period_window.dart';
import 'package:pose_estimation_app/features/challenges/domain/models/challenge_progress.dart';
import 'package:pose_estimation_app/features/goals/application/repositories/workout_goal_repository.dart';
import 'package:pose_estimation_app/features/goals/domain/models/user_workout_goal.dart';
import 'package:pose_estimation_app/features/goals/presentation/models/challenge_goals_state.dart';
import 'package:pose_estimation_app/features/goals/presentation/models/workout_goal.dart';
import 'package:pose_estimation_app/features/goals/presentation/providers/goals_provider.dart';
import 'package:pose_estimation_app/features/goals/presentation/screens/goals_screen.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_type.dart';
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
      overrides: [
        goalsProvider.overrideWith((ref) => completer.future),
        _challengeOverride(),
      ],
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    completer.complete(
      const GoalsState(source: GoalsDataSource.empty, goals: <WorkoutGoal>[]),
    );
    await tester.pumpAndSettle();

    final verticalScrollable = _verticalScrollable();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('goal-template-weeklySessions')),
      220,
      scrollable: verticalScrollable,
    );
    await tester.pumpAndSettle();

    expect(find.text('Önerilen hedefler'), findsOneWidget);
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
        _challengeOverride(),
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

  testWidgets('shows one active goal and keeps paused goals collapsed', (
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
        _challengeOverride(),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('active-goal-card')), findsOneWidget);
    expect(find.text('Haftada 4 analiz'), findsOneWidget);
    expect(find.text('Düzenle'), findsOneWidget);
    expect(find.text('Duraklat'), findsOneWidget);

    final verticalScrollable = _verticalScrollable();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('archived-goals-panel')),
      220,
      scrollable: verticalScrollable,
    );
    await tester.tap(find.text('Tamamlanan ve duraklatılan hedefler'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('paused-goal-weeklyReps')),
      findsOneWidget,
    );
    expect(find.text('Haftada 150 tekrar'), findsOneWidget);
  });

  testWidgets('shows medal progress and nearby goals without a badge wall', (
    WidgetTester tester,
  ) async {
    final challengeState = _challengeState(
      period: ChallengePeriod.daily,
      values: const <ExerciseType, double>{
        ExerciseType.pushUp: 12,
        ExerciseType.squat: 28,
        ExerciseType.plank: 40,
      },
    );

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
        challengeGoalsProvider.overrideWith((ref) async => challengeState),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('Madalya hedefleri'), findsOneWidget);
    expect(find.byKey(const ValueKey('medal-challenge-card')), findsOneWidget);
    expect(find.text('28 güvenilir tekrar'), findsOneWidget);
    expect(find.text('Sana yakın hedefler'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('nearby-medal-goals-list')),
      findsOneWidget,
    );
    expect(find.text('Kilitli başarımlar'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('challenge-exercise-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Şınav').last);
    await tester.pumpAndSettle();

    expect(find.text('12 güvenilir tekrar'), findsOneWidget);
  });

  testWidgets('switches medal periods without replacing the personal goal', (
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
                targetValue: 5,
                currentValue: 2,
                unit: '',
                description: '',
                isCompleted: false,
                type: WorkoutGoalType.weeklySessions,
              ),
            ],
          ),
        ),
        challengeGoalsProvider.overrideWith((ref) async {
          final period = ref.watch(selectedChallengePeriodProvider);
          return _challengeState(
            period: period,
            values: <ExerciseType, double>{
              ExerciseType.pushUp: switch (period) {
                ChallengePeriod.daily => 10,
                ChallengePeriod.weekly => 70,
                ChallengePeriod.monthly => 200,
              },
            },
          );
        }),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('Bugün'), findsOneWidget);
    await tester.tap(find.text('Haftalık'));
    await tester.pumpAndSettle();

    expect(find.text('Bu hafta'), findsOneWidget);
    expect(find.text('Haftada 5 analiz'), findsOneWidget);
  });

  testWidgets('keeps medal progress failure local to its section', (
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
        challengeGoalsProvider.overrideWith(
          (ref) => Future<ChallengeGoalsState>.error(StateError('offline')),
        ),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('challenge-goals-error')), findsOneWidget);
    expect(find.text('Önerilen hedefler'), findsOneWidget);
    expect(find.byKey(const ValueKey('no-active-goal')), findsOneWidget);
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
        _challengeOverride(),
      ],
    );
    await tester.pumpAndSettle();

    final template = find.byKey(const ValueKey('goal-template-weeklySessions'));
    final verticalScrollable = _verticalScrollable();
    await tester.scrollUntilVisible(
      template,
      220,
      scrollable: verticalScrollable,
    );
    await tester.tap(template);
    await tester.pumpAndSettle();

    expect(find.text('Hızlı seçim'), findsOneWidget);
    expect(find.byKey(const ValueKey('goal-target-field')), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('goal-target-field')),
      '7',
    );
    await tester.tap(find.text('Başlat').last);
    await tester.pumpAndSettle();

    expect(repository.goals.single.targetValue, 7);
    expect(repository.goals.single.status, WorkoutGoalStatus.active);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('active-goal-card')),
      -220,
      scrollable: verticalScrollable,
    );
    await tester.pumpAndSettle();

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
        _challengeOverride(),
      ],
    );
    await tester.pumpAndSettle();

    final verticalScrollable = _verticalScrollable();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('goal-template-weeklyReps')),
      220,
      scrollable: verticalScrollable,
    );

    expect(
      find.byKey(const ValueKey('goal-template-weeklyReps')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('goal-template-averageScore')),
      findsNothing,
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
        _challengeOverride(),
      ],
    );
    await tester.pumpAndSettle();

    final template = find.byKey(const ValueKey('goal-template-weeklySessions'));
    await tester.scrollUntilVisible(
      template,
      220,
      scrollable: _verticalScrollable(),
    );
    await tester.tap(template);
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

Override _challengeOverride() {
  return challengeGoalsProvider.overrideWith(
    (ref) async => _challengeState(period: ChallengePeriod.daily),
  );
}

ChallengeGoalsState _challengeState({
  required ChallengePeriod period,
  Map<ExerciseType, double> values = const <ExerciseType, double>{},
}) {
  const catalog = ChallengeCatalog();
  final window = ChallengePeriodWindow.forInstant(
    period: period,
    instant: DateTime.utc(2026, 8, 7, 12),
    timezoneOffset: Duration.zero,
  );
  return ChallengeGoalsState(
    period: period,
    window: window,
    progresses: catalog.definitions
        .map(
          (definition) => ChallengeProgress(
            definition: definition,
            period: period,
            value: values[definition.exerciseType] ?? 0,
          ),
        )
        .toList(growable: false),
  );
}

Finder _verticalScrollable() {
  return find.byWidgetPredicate(
    (widget) =>
        widget is Scrollable && widget.axisDirection == AxisDirection.down,
  );
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
    final index = goals.indexWhere(
      (goal) => goal.ownerId == ownerId && goal.type == type,
    );
    if (index == -1) return;
    goals[index] = goals[index].copyWith(
      status: WorkoutGoalStatus.paused,
      updatedAt: now,
    );
  }
}
