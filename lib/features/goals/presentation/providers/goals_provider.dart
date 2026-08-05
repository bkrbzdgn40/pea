import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../workout_analysis/application/workout_statistics_calculator.dart';
import '../../../workout_analysis/presentation/providers/user_sessions_snapshot_provider.dart';
import '../../application/goal_progress_calculator.dart';
import '../../application/repositories/workout_goal_repository.dart';
import '../../domain/models/user_workout_goal.dart';
import '../../domain/models/workout_goal_template.dart';
import '../../infrastructure/repositories/firestore_workout_goal_repository.dart';
import '../models/workout_goal.dart';

final workoutGoalRepositoryProvider = Provider<WorkoutGoalRepository>((ref) {
  return FirestoreWorkoutGoalRepository(ref.watch(firebaseFirestoreProvider));
});

final goalsClockProvider = Provider<DateTime Function()>((ref) {
  return DateTime.now;
});

final goalsProvider = FutureProvider<GoalsState>((ref) async {
  final ownerId = ref.watch(currentUserIdProvider);

  if (ownerId == null) {
    return const GoalsState(
      goals: <WorkoutGoal>[],
      source: GoalsDataSource.noUser,
      templates: workoutGoalTemplates,
    );
  }

  try {
    final definitions = await ref
        .read(workoutGoalRepositoryProvider)
        .listGoals(ownerId: ownerId);
    final snapshot = await ref.watch(userSessionsSnapshotProvider.future);
    final progressAvailable =
        snapshot.source == UserSessionsSnapshotSource.real ||
        snapshot.source == UserSessionsSnapshotSource.empty;
    final statistics = WorkoutStatisticsCalculator().calculate(
      snapshot.sessions,
    );
    const progressCalculator = GoalProgressCalculator();
    final goals = definitions
        .map((definition) {
          final currentValue = progressAvailable
              ? progressCalculator.currentValue(
                  type: definition.type,
                  statistics: statistics,
                )
              : 0.0;
          return WorkoutGoal(
            id: definition.id,
            title: '',
            targetValue: definition.targetValue,
            currentValue: currentValue,
            unit: '',
            description: '',
            isCompleted:
                progressAvailable && currentValue >= definition.targetValue,
            type: definition.type,
            status: definition.status,
            progressAvailable: progressAvailable,
          );
        })
        .toList(growable: false);

    return GoalsState(
      goals: goals,
      source: goals.isEmpty ? GoalsDataSource.empty : GoalsDataSource.real,
      ownerId: ownerId,
      templates: workoutGoalTemplates,
      progressAvailable: progressAvailable,
    );
  } catch (_) {
    return GoalsState(
      goals: const <WorkoutGoal>[],
      source: GoalsDataSource.error,
      ownerId: ownerId,
      templates: workoutGoalTemplates,
      progressAvailable: false,
    );
  }
});

final goalManagementControllerProvider =
    StateNotifierProvider<GoalManagementController, GoalManagementState>((ref) {
      return GoalManagementController(
        readRepository: () => ref.read(workoutGoalRepositoryProvider),
        readOwnerId: () => ref.read(currentUserIdProvider),
        clock: ref.watch(goalsClockProvider),
        onGoalsChanged: () => ref.invalidate(goalsProvider),
      );
    });

class GoalManagementController extends StateNotifier<GoalManagementState> {
  GoalManagementController({
    required WorkoutGoalRepository Function() readRepository,
    required String? Function() readOwnerId,
    required DateTime Function() clock,
    required void Function() onGoalsChanged,
  }) : _readRepository = readRepository,
       _readOwnerId = readOwnerId,
       _clock = clock,
       _onGoalsChanged = onGoalsChanged,
       super(const GoalManagementState());

  final WorkoutGoalRepository Function() _readRepository;
  final String? Function() _readOwnerId;
  final DateTime Function() _clock;
  final void Function() _onGoalsChanged;

  Future<bool> activateGoal({
    required WorkoutGoalType type,
    required double targetValue,
  }) async {
    final template = templateForGoalType(type);
    if (!template.accepts(targetValue)) {
      state = const GoalManagementState(
        error: GoalManagementError.invalidTarget,
      );
      return false;
    }

    final ownerId = _currentOwnerId;
    if (ownerId == null) {
      state = const GoalManagementState(error: GoalManagementError.noUser);
      return false;
    }

    state = const GoalManagementState(isSaving: true);
    try {
      await _readRepository().activateGoal(
        ownerId: ownerId,
        type: type,
        targetValue: targetValue,
        now: _clock(),
      );
      _onGoalsChanged();
      state = const GoalManagementState();
      return true;
    } catch (_) {
      state = const GoalManagementState(error: GoalManagementError.saveFailed);
      return false;
    }
  }

  Future<bool> pauseGoal(WorkoutGoalType type) async {
    final ownerId = _currentOwnerId;
    if (ownerId == null) {
      state = const GoalManagementState(error: GoalManagementError.noUser);
      return false;
    }

    state = const GoalManagementState(isSaving: true);
    try {
      await _readRepository().pauseGoal(
        ownerId: ownerId,
        type: type,
        now: _clock(),
      );
      _onGoalsChanged();
      state = const GoalManagementState();
      return true;
    } catch (_) {
      state = const GoalManagementState(error: GoalManagementError.saveFailed);
      return false;
    }
  }

  String? get _currentOwnerId => _readOwnerId();
}

class GoalManagementState {
  const GoalManagementState({this.isSaving = false, this.error});

  final bool isSaving;
  final GoalManagementError? error;
}

enum GoalManagementError { noUser, invalidTarget, saveFailed }

class GoalsState {
  const GoalsState({
    required this.goals,
    required this.source,
    this.ownerId,
    this.templates = workoutGoalTemplates,
    this.progressAvailable = true,
  });

  final List<WorkoutGoal> goals;
  final GoalsDataSource source;
  final String? ownerId;
  final List<WorkoutGoalTemplate> templates;
  final bool progressAvailable;

  bool get isFallback => source != GoalsDataSource.real;

  WorkoutGoal? get activeGoal {
    for (final goal in goals) {
      if (goal.isActive) return goal;
    }
    return null;
  }

  List<WorkoutGoal> get pausedGoals => goals
      .where((goal) => goal.status == WorkoutGoalStatus.paused)
      .toList(growable: false);

  String get sourceMessage {
    return switch (source) {
      GoalsDataSource.real => 'Kullanıcı hedefleri',
      GoalsDataSource.noUser => 'Kullanıcı oturumu bulunamadı',
      GoalsDataSource.empty => 'Henüz hedef seçilmedi',
      GoalsDataSource.error => 'Hedef verisi alınamadı',
    };
  }
}

enum GoalsDataSource { real, noUser, empty, error }
