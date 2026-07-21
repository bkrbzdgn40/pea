import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/workout_engine.dart';
import '../../application/workout_state.dart';
import '../../domain/models/exercise_type.dart';

class WorkoutPlanSessionState {
  const WorkoutPlanSessionState({this.plan, this.snapshot});

  final WorkoutPlan? plan;
  final WorkoutEngineSnapshot? snapshot;

  bool get hasPlan => plan != null && snapshot != null;

  bool get isActive =>
      snapshot?.phase == WorkoutEnginePhase.active ||
      snapshot?.phase == WorkoutEnginePhase.setCompleted;

  bool get isSetCompleted => snapshot?.isSetCompleted ?? false;

  bool get isWorkoutCompleted => snapshot?.isWorkoutCompleted ?? false;
}

final workoutPlanSessionProvider =
    NotifierProvider<WorkoutPlanSessionController, WorkoutPlanSessionState>(
      WorkoutPlanSessionController.new,
    );

class WorkoutPlanSessionController extends Notifier<WorkoutPlanSessionState> {
  WorkoutEngine? _engine;

  @override
  WorkoutPlanSessionState build() => const WorkoutPlanSessionState();

  WorkoutEngineSnapshot start(WorkoutPlan plan) {
    final engine = WorkoutEngine(plan: plan);
    _engine = engine;
    final snapshot = engine.start();
    state = WorkoutPlanSessionState(plan: plan, snapshot: snapshot);
    return snapshot;
  }

  WorkoutEngineSnapshot? observe({
    required ExerciseType exercise,
    required WorkoutState workoutState,
  }) {
    final engine = _engine;
    final snapshot = state.snapshot;
    if (engine == null ||
        snapshot == null ||
        snapshot.phase != WorkoutEnginePhase.active ||
        snapshot.currentExercise != exercise) {
      return snapshot;
    }

    if (snapshot.targetRepetitions != null &&
        workoutState.rangeRepAnalysis == null) {
      return snapshot;
    }
    if (snapshot.targetHoldDuration != null &&
        workoutState.holdAnalysis == null) {
      return snapshot;
    }

    final next = workoutState.rangeRepAnalysis != null
        ? engine.observe(
            WorkoutProgressObservation.repetitions(
              exercise: exercise,
              cumulativeRepCount: workoutState.repCount,
            ),
          )
        : engine.observe(
            WorkoutProgressObservation.hold(
              exercise: exercise,
              currentHoldDuration: Duration(
                milliseconds: (workoutState.currentHoldSeconds * 1000).round(),
              ),
            ),
          );
    state = WorkoutPlanSessionState(plan: state.plan, snapshot: next);
    return next;
  }

  ExerciseType? get nextExerciseAfterCompletedSet {
    final plan = state.plan;
    final snapshot = state.snapshot;
    if (plan == null || snapshot == null || !snapshot.isSetCompleted) {
      return null;
    }

    if (snapshot.setNumber < snapshot.setsInCurrentExercise) {
      return snapshot.currentExercise;
    }
    if (snapshot.exerciseIndex < snapshot.exerciseCount) {
      return plan.exercises[snapshot.exerciseIndex].exercise;
    }
    if (snapshot.roundNumber < snapshot.totalRounds) {
      return plan.exercises.first.exercise;
    }
    return null;
  }

  WorkoutEngineSnapshot advance() {
    final engine = _engine;
    if (engine == null) {
      throw StateError('No active workout plan.');
    }
    final snapshot = engine.advance();
    state = WorkoutPlanSessionState(plan: state.plan, snapshot: snapshot);
    return snapshot;
  }

  void reset() {
    _engine?.reset();
    _engine = null;
    state = const WorkoutPlanSessionState();
  }
}
