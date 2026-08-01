import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/workout_engine.dart';
import '../../application/workout_state.dart';
import '../../domain/models/exercise_type.dart';
import 'selected_exercise_provider.dart';

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
  // Hold progress stays responsive without mirroring the pose pipeline cadence.
  static const Duration _holdObservationInterval = Duration(milliseconds: 250);

  WorkoutEngine? _engine;
  ExerciseType? _lastForwardedExercise;
  int? _lastForwardedRepCount;
  int? _lastForwardedValidatedAttemptIndex;
  Duration? _lastForwardedHoldDuration;
  ExerciseType? _selectedExerciseBeforePlan;
  bool _restoreSelectedExerciseOnReset = false;

  @override
  WorkoutPlanSessionState build() => const WorkoutPlanSessionState();

  WorkoutEngineSnapshot start(
    WorkoutPlan plan, {
    ExerciseType? selectedExerciseBeforePlan,
    bool restoreSelectedExerciseOnReset = false,
  }) {
    final engine = WorkoutEngine(plan: plan);
    _engine = engine;
    final snapshot = engine.start();
    _seedObservationGate(snapshot);
    _selectedExerciseBeforePlan = selectedExerciseBeforePlan;
    _restoreSelectedExerciseOnReset = restoreSelectedExerciseOnReset;
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

    final WorkoutEngineSnapshot next;
    if (workoutState.rangeRepAnalysis != null) {
      final event = workoutState.validatedRepEvent;
      if (event != null) {
        if (_lastForwardedValidatedAttemptIndex == event.attemptIndex) {
          return snapshot;
        }
        _lastForwardedValidatedAttemptIndex = event.attemptIndex;
        if (!event.countsTowardReps) {
          return snapshot;
        }
      }
      final repCount = event?.acceptedRepIndex ?? workoutState.repCount;
      if (_lastForwardedExercise == exercise &&
          _lastForwardedRepCount == repCount) {
        return snapshot;
      }

      next = engine.observe(
        WorkoutProgressObservation.repetitions(
          exercise: exercise,
          cumulativeRepCount: repCount,
        ),
      );
      _lastForwardedExercise = exercise;
      _lastForwardedRepCount = repCount;
      _lastForwardedHoldDuration = null;
    } else {
      final holdDuration = Duration(
        milliseconds: (workoutState.currentHoldSeconds * 1000).round(),
      );
      if (!_shouldForwardHoldObservation(
        exercise: exercise,
        snapshot: snapshot,
        holdDuration: holdDuration,
      )) {
        return snapshot;
      }

      next = engine.observe(
        WorkoutProgressObservation.hold(
          exercise: exercise,
          currentHoldDuration: holdDuration,
        ),
      );
      _lastForwardedExercise = exercise;
      _lastForwardedRepCount = null;
      _lastForwardedHoldDuration = holdDuration;
    }

    state = WorkoutPlanSessionState(plan: state.plan, snapshot: next);
    return next;
  }

  bool _shouldForwardHoldObservation({
    required ExerciseType exercise,
    required WorkoutEngineSnapshot snapshot,
    required Duration holdDuration,
  }) {
    final lastDuration = _lastForwardedHoldDuration;
    if (_lastForwardedExercise != exercise || lastDuration == null) {
      return true;
    }

    if (holdDuration.compareTo(lastDuration) < 0) {
      return true;
    }

    final target = snapshot.targetHoldDuration;
    if (target != null &&
        holdDuration.compareTo(target) >= 0 &&
        lastDuration.compareTo(target) < 0) {
      return true;
    }

    return holdDuration.inMilliseconds ~/
            _holdObservationInterval.inMilliseconds !=
        lastDuration.inMilliseconds ~/ _holdObservationInterval.inMilliseconds;
  }

  void _seedObservationGate(
    WorkoutEngineSnapshot snapshot, {
    bool preserveForSameExercise = false,
  }) {
    final exercise = snapshot.currentExercise;
    if (preserveForSameExercise && exercise == _lastForwardedExercise) {
      return;
    }

    _lastForwardedExercise = exercise;
    _lastForwardedRepCount = snapshot.targetRepetitions == null ? null : 0;
    _lastForwardedHoldDuration = snapshot.targetHoldDuration == null
        ? null
        : Duration.zero;
    _lastForwardedValidatedAttemptIndex = null;
  }

  void _clearObservationGate() {
    _lastForwardedExercise = null;
    _lastForwardedRepCount = null;
    _lastForwardedHoldDuration = null;
    _lastForwardedValidatedAttemptIndex = null;
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

  WorkoutEngineSnapshot advance({WorkoutState? resumeState}) {
    final engine = _engine;
    if (engine == null) {
      throw StateError('No active workout plan.');
    }
    final previousExercise = state.snapshot?.currentExercise;
    final snapshot = resumeState == null
        ? engine.advance()
        : engine.advance(
            repetitionBaseline: resumeState.rangeRepAnalysis == null
                ? null
                : resumeState.repCount,
            holdBaseline: resumeState.holdAnalysis == null
                ? null
                : Duration(
                    milliseconds: (resumeState.currentHoldSeconds * 1000)
                        .round(),
                  ),
          );
    _seedObservationGate(
      snapshot,
      preserveForSameExercise: snapshot.currentExercise == previousExercise,
    );
    state = WorkoutPlanSessionState(plan: state.plan, snapshot: snapshot);
    return snapshot;
  }

  void reset() {
    final shouldRestoreSelection =
        state.hasPlan && _restoreSelectedExerciseOnReset;
    final selectionBeforePlan = _selectedExerciseBeforePlan;
    _engine?.reset();
    _engine = null;
    _clearObservationGate();
    _selectedExerciseBeforePlan = null;
    _restoreSelectedExerciseOnReset = false;
    state = const WorkoutPlanSessionState();
    if (shouldRestoreSelection) {
      ref.read(selectedExerciseProvider.notifier).state = selectionBeforePlan;
    }
  }
}
