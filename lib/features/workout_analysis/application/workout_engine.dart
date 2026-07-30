import '../domain/models/exercise_type.dart';
import 'exercise_catalog.dart';
import 'exercise_definition_metadata.dart';

enum WorkoutTargetType { repetitions, holdDuration }

class WorkoutTarget {
  const WorkoutTarget.repetitions(int repetitions)
    : type = WorkoutTargetType.repetitions,
      // The public input stays non-null while the union field is nullable.
      // ignore: prefer_initializing_formals
      repetitions = repetitions,
      holdDuration = null;

  const WorkoutTarget.hold(Duration duration)
    : type = WorkoutTargetType.holdDuration,
      repetitions = null,
      holdDuration = duration;

  final WorkoutTargetType type;
  final int? repetitions;
  final Duration? holdDuration;
}

class WorkoutExerciseBlock {
  const WorkoutExerciseBlock({
    required this.exercise,
    required this.target,
    this.sets = 1,
    this.restAfterSet = const Duration(seconds: 60),
  });

  final ExerciseType exercise;
  final WorkoutTarget target;
  final int sets;
  final Duration restAfterSet;
}

class WorkoutPlan {
  WorkoutPlan({
    required List<WorkoutExerciseBlock> exercises,
    this.rounds = 1,
    this.id,
    this.name = '',
  }) : exercises = List<WorkoutExerciseBlock>.unmodifiable(exercises);

  final List<WorkoutExerciseBlock> exercises;
  final int rounds;
  final String? id;
  final String name;
}

enum WorkoutEnginePhase { idle, active, setCompleted, completed }

enum WorkoutProgressObservationType { repetitions, holdDuration }

class WorkoutProgressObservation {
  const WorkoutProgressObservation.repetitions({
    required this.exercise,
    required int cumulativeRepCount,
  }) : type = WorkoutProgressObservationType.repetitions,
       // The public input stays non-null while the union field is nullable.
       // ignore: prefer_initializing_formals
       cumulativeRepCount = cumulativeRepCount,
       currentHoldDuration = null;

  const WorkoutProgressObservation.hold({
    required this.exercise,
    required Duration currentHoldDuration,
  }) : type = WorkoutProgressObservationType.holdDuration,
       cumulativeRepCount = null,
       // The public input stays non-null while the union field is nullable.
       // ignore: prefer_initializing_formals
       currentHoldDuration = currentHoldDuration;

  final ExerciseType exercise;
  final WorkoutProgressObservationType type;
  final int? cumulativeRepCount;
  final Duration? currentHoldDuration;
}

class WorkoutSetResult {
  const WorkoutSetResult({
    required this.exercise,
    required this.roundNumber,
    required this.exerciseIndex,
    required this.setNumber,
    required this.target,
    required this.completedAt,
    required this.repetitions,
    required this.holdDuration,
  });

  final ExerciseType exercise;
  final int roundNumber;
  final int exerciseIndex;
  final int setNumber;
  final WorkoutTarget target;
  final DateTime completedAt;
  final int repetitions;
  final Duration holdDuration;
}

class WorkoutExerciseAggregate {
  const WorkoutExerciseAggregate({
    required this.exercise,
    required this.completedSets,
    required this.totalRepetitions,
    required this.totalHoldDuration,
  });

  final ExerciseType exercise;
  final int completedSets;
  final int totalRepetitions;
  final Duration totalHoldDuration;
}

class WorkoutEngineSummary {
  WorkoutEngineSummary({
    required this.completedSets,
    required this.totalSets,
    required this.totalRepetitions,
    required this.totalHoldDuration,
    required this.startedAt,
    required this.completedAt,
    required Map<ExerciseType, WorkoutExerciseAggregate> exerciseAggregates,
  }) : exerciseAggregates =
           Map<ExerciseType, WorkoutExerciseAggregate>.unmodifiable(
             exerciseAggregates,
           );

  final int completedSets;
  final int totalSets;
  final int totalRepetitions;
  final Duration totalHoldDuration;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final Map<ExerciseType, WorkoutExerciseAggregate> exerciseAggregates;

  Duration get elapsed {
    final startedAt = this.startedAt;
    if (startedAt == null) {
      return Duration.zero;
    }

    final end = completedAt;
    if (end == null) {
      return Duration.zero;
    }

    return end.difference(startedAt);
  }
}

class WorkoutEngineSnapshot {
  WorkoutEngineSnapshot({
    required this.phase,
    required this.currentExercise,
    required this.roundNumber,
    required this.totalRounds,
    required this.exerciseIndex,
    required this.exerciseCount,
    required this.setNumber,
    required this.setsInCurrentExercise,
    required this.completedSets,
    required this.totalSets,
    required this.currentRepetitions,
    required this.targetRepetitions,
    required this.currentHoldDuration,
    required this.targetHoldDuration,
    required this.restAfterSet,
    required this.progress,
    required this.startedAt,
    required this.completedAt,
    required List<WorkoutSetResult> completedSetResults,
    required this.summary,
  }) : completedSetResults = List<WorkoutSetResult>.unmodifiable(
         completedSetResults,
       );

  final WorkoutEnginePhase phase;
  final ExerciseType? currentExercise;
  final int roundNumber;
  final int totalRounds;
  final int exerciseIndex;
  final int exerciseCount;
  final int setNumber;
  final int setsInCurrentExercise;
  final int completedSets;
  final int totalSets;
  final int currentRepetitions;
  final int? targetRepetitions;
  final Duration currentHoldDuration;
  final Duration? targetHoldDuration;
  final Duration restAfterSet;
  final double progress;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final List<WorkoutSetResult> completedSetResults;
  final WorkoutEngineSummary summary;

  bool get isActive => phase == WorkoutEnginePhase.active;

  bool get isSetCompleted => phase == WorkoutEnginePhase.setCompleted;

  bool get isWorkoutCompleted => phase == WorkoutEnginePhase.completed;
}

/// Orchestrates a multi-exercise workout plan without owning pose analysis or
/// persistence.
///
/// The engine intentionally consumes already-computed rep/hold progress. It is
/// therefore independent from camera, UI, Firestore, voice, and haptic layers.
/// A completed set pauses in [WorkoutEnginePhase.setCompleted] until [advance]
/// is called so continuous camera frames cannot silently roll into the next set
/// or exercise.
class WorkoutEngine {
  WorkoutEngine({
    required WorkoutPlan plan,
    ExerciseCatalog exerciseCatalog = const ExerciseCatalog(),
    DateTime Function()? clock,
  }) : _plan = plan,
       _exerciseCatalog = exerciseCatalog,
       _clock = clock ?? DateTime.now {
    _validatePlan();
  }

  final WorkoutPlan _plan;
  final ExerciseCatalog _exerciseCatalog;
  final DateTime Function() _clock;
  final List<WorkoutSetResult> _completedSetResults = <WorkoutSetResult>[];

  WorkoutEnginePhase _phase = WorkoutEnginePhase.idle;
  int _roundIndex = 0;
  int _exerciseIndex = 0;
  int _setIndex = 0;
  int _repBaseline = 0;
  int _lastObservedRepCount = 0;
  Duration _holdBaseline = Duration.zero;
  Duration _lastObservedHoldDuration = Duration.zero;
  int _currentRepetitions = 0;
  Duration _currentHoldDuration = Duration.zero;
  DateTime? _startedAt;
  DateTime? _completedAt;

  WorkoutPlan get plan => _plan;

  WorkoutEngineSnapshot get snapshot => _buildSnapshot();

  WorkoutEngineSnapshot start() {
    if (_phase != WorkoutEnginePhase.idle) {
      throw StateError('WorkoutEngine can only be started from idle state.');
    }

    _phase = WorkoutEnginePhase.active;
    _roundIndex = 0;
    _exerciseIndex = 0;
    _setIndex = 0;
    _repBaseline = 0;
    _lastObservedRepCount = 0;
    _holdBaseline = Duration.zero;
    _lastObservedHoldDuration = Duration.zero;
    _currentRepetitions = 0;
    _currentHoldDuration = Duration.zero;
    _completedSetResults.clear();
    _startedAt = _clock();
    _completedAt = null;

    return _buildSnapshot();
  }

  WorkoutEngineSnapshot observe(WorkoutProgressObservation observation) {
    if (_phase != WorkoutEnginePhase.active) {
      return _buildSnapshot();
    }

    final currentBlock = _currentBlock;
    if (observation.exercise != currentBlock.exercise) {
      throw ArgumentError.value(
        observation.exercise,
        'observation.exercise',
        'Progress belongs to ${currentBlock.exercise.id}.',
      );
    }

    switch (currentBlock.target.type) {
      case WorkoutTargetType.repetitions:
        _observeRepetitions(observation, currentBlock);
        break;
      case WorkoutTargetType.holdDuration:
        _observeHold(observation, currentBlock);
        break;
    }

    return _buildSnapshot();
  }

  WorkoutEngineSnapshot advance({
    int? repetitionBaseline,
    Duration? holdBaseline,
  }) {
    if (_phase != WorkoutEnginePhase.setCompleted) {
      throw StateError('WorkoutEngine can only advance after a completed set.');
    }

    final previousExercise = _currentBlock.exercise;
    final previousRepCount = _lastObservedRepCount;
    final previousHoldDuration = _lastObservedHoldDuration;

    if (_setIndex + 1 < _currentBlock.sets) {
      _setIndex += 1;
    } else if (_exerciseIndex + 1 < _plan.exercises.length) {
      _exerciseIndex += 1;
      _setIndex = 0;
    } else if (_roundIndex + 1 < _plan.rounds) {
      _roundIndex += 1;
      _exerciseIndex = 0;
      _setIndex = 0;
    } else {
      _phase = WorkoutEnginePhase.completed;
      _completedAt = _clock();
      _currentRepetitions = 0;
      _currentHoldDuration = Duration.zero;
      return _buildSnapshot();
    }

    final nextExercise = _currentBlock.exercise;
    final isSameExercise = nextExercise == previousExercise;
    final effectiveRepBaseline = repetitionBaseline ?? previousRepCount;
    final effectiveHoldBaseline = holdBaseline ?? previousHoldDuration;
    _repBaseline = isSameExercise ? effectiveRepBaseline : 0;
    _lastObservedRepCount = isSameExercise ? effectiveRepBaseline : 0;
    _holdBaseline = isSameExercise ? effectiveHoldBaseline : Duration.zero;
    _lastObservedHoldDuration = isSameExercise
        ? effectiveHoldBaseline
        : Duration.zero;
    _currentRepetitions = 0;
    _currentHoldDuration = Duration.zero;
    _phase = WorkoutEnginePhase.active;

    return _buildSnapshot();
  }

  WorkoutEngineSnapshot reset() {
    _phase = WorkoutEnginePhase.idle;
    _roundIndex = 0;
    _exerciseIndex = 0;
    _setIndex = 0;
    _repBaseline = 0;
    _lastObservedRepCount = 0;
    _holdBaseline = Duration.zero;
    _lastObservedHoldDuration = Duration.zero;
    _currentRepetitions = 0;
    _currentHoldDuration = Duration.zero;
    _completedSetResults.clear();
    _startedAt = null;
    _completedAt = null;

    return _buildSnapshot();
  }

  WorkoutExerciseBlock get _currentBlock => _plan.exercises[_exerciseIndex];

  int get _totalSets =>
      _plan.rounds *
      _plan.exercises.fold<int>(0, (total, block) => total + block.sets);

  void _observeRepetitions(
    WorkoutProgressObservation observation,
    WorkoutExerciseBlock block,
  ) {
    if (observation.type != WorkoutProgressObservationType.repetitions) {
      throw ArgumentError(
        'Repetition target requires a repetition progress observation.',
      );
    }

    final cumulativeRepCount = observation.cumulativeRepCount!;
    if (cumulativeRepCount < 0) {
      throw ArgumentError.value(
        cumulativeRepCount,
        'cumulativeRepCount',
        'Rep count cannot be negative.',
      );
    }

    if (cumulativeRepCount < _lastObservedRepCount) {
      _repBaseline = 0;
    }

    _lastObservedRepCount = cumulativeRepCount;
    _currentRepetitions = cumulativeRepCount - _repBaseline;
    if (_currentRepetitions < 0) {
      _currentRepetitions = cumulativeRepCount;
      _repBaseline = 0;
    }

    final targetRepetitions = block.target.repetitions!;
    if (_currentRepetitions >= targetRepetitions) {
      _completeCurrentSet(
        repetitions: _currentRepetitions,
        holdDuration: Duration.zero,
      );
    }
  }

  void _observeHold(
    WorkoutProgressObservation observation,
    WorkoutExerciseBlock block,
  ) {
    if (observation.type != WorkoutProgressObservationType.holdDuration) {
      throw ArgumentError('Hold target requires a hold progress observation.');
    }

    final observedHoldDuration = observation.currentHoldDuration!;
    if (observedHoldDuration.isNegative) {
      throw ArgumentError.value(
        observedHoldDuration,
        'currentHoldDuration',
        'Hold duration cannot be negative.',
      );
    }

    if (observedHoldDuration.compareTo(_lastObservedHoldDuration) < 0) {
      _holdBaseline = Duration.zero;
    }

    _lastObservedHoldDuration = observedHoldDuration;
    _currentHoldDuration = observedHoldDuration - _holdBaseline;
    if (_currentHoldDuration.isNegative) {
      _currentHoldDuration = observedHoldDuration;
      _holdBaseline = Duration.zero;
    }

    final targetHoldDuration = block.target.holdDuration!;
    if (_currentHoldDuration.compareTo(targetHoldDuration) >= 0) {
      _completeCurrentSet(repetitions: 0, holdDuration: _currentHoldDuration);
    }
  }

  void _completeCurrentSet({
    required int repetitions,
    required Duration holdDuration,
  }) {
    if (_phase != WorkoutEnginePhase.active) {
      return;
    }

    final block = _currentBlock;
    _completedSetResults.add(
      WorkoutSetResult(
        exercise: block.exercise,
        roundNumber: _roundIndex + 1,
        exerciseIndex: _exerciseIndex + 1,
        setNumber: _setIndex + 1,
        target: block.target,
        completedAt: _clock(),
        repetitions: repetitions,
        holdDuration: holdDuration,
      ),
    );
    _phase = WorkoutEnginePhase.setCompleted;
  }

  WorkoutEngineSnapshot _buildSnapshot() {
    final hasCurrentStep =
        _phase != WorkoutEnginePhase.idle &&
        _phase != WorkoutEnginePhase.completed;
    final block = hasCurrentStep ? _currentBlock : null;
    final target = block?.target;
    final targetRepetitions = target?.repetitions;
    final targetHoldDuration = target?.holdDuration;

    var progress = 0.0;
    if (target?.type == WorkoutTargetType.repetitions &&
        targetRepetitions != null &&
        targetRepetitions > 0) {
      progress = _currentRepetitions / targetRepetitions;
    } else if (target?.type == WorkoutTargetType.holdDuration &&
        targetHoldDuration != null &&
        targetHoldDuration.inMicroseconds > 0) {
      progress =
          _currentHoldDuration.inMicroseconds /
          targetHoldDuration.inMicroseconds;
    }

    return WorkoutEngineSnapshot(
      phase: _phase,
      currentExercise: block?.exercise,
      roundNumber: hasCurrentStep ? _roundIndex + 1 : 0,
      totalRounds: _plan.rounds,
      exerciseIndex: hasCurrentStep ? _exerciseIndex + 1 : 0,
      exerciseCount: _plan.exercises.length,
      setNumber: hasCurrentStep ? _setIndex + 1 : 0,
      setsInCurrentExercise: block?.sets ?? 0,
      completedSets: _completedSetResults.length,
      totalSets: _totalSets,
      currentRepetitions: _currentRepetitions,
      targetRepetitions: targetRepetitions,
      currentHoldDuration: _currentHoldDuration,
      targetHoldDuration: targetHoldDuration,
      restAfterSet: block?.restAfterSet ?? Duration.zero,
      progress: progress.clamp(0.0, 1.0).toDouble(),
      startedAt: _startedAt,
      completedAt: _completedAt,
      completedSetResults: _completedSetResults,
      summary: _buildSummary(),
    );
  }

  WorkoutEngineSummary _buildSummary() {
    final mutableAggregates = <ExerciseType, _MutableExerciseAggregate>{};
    var totalRepetitions = 0;
    var totalHoldDuration = Duration.zero;

    for (final result in _completedSetResults) {
      totalRepetitions += result.repetitions;
      totalHoldDuration += result.holdDuration;
      final aggregate = mutableAggregates.putIfAbsent(
        result.exercise,
        () => _MutableExerciseAggregate(result.exercise),
      );
      aggregate.completedSets += 1;
      aggregate.totalRepetitions += result.repetitions;
      aggregate.totalHoldDuration += result.holdDuration;
    }

    final aggregates = <ExerciseType, WorkoutExerciseAggregate>{
      for (final entry in mutableAggregates.entries)
        entry.key: WorkoutExerciseAggregate(
          exercise: entry.value.exercise,
          completedSets: entry.value.completedSets,
          totalRepetitions: entry.value.totalRepetitions,
          totalHoldDuration: entry.value.totalHoldDuration,
        ),
    };

    return WorkoutEngineSummary(
      completedSets: _completedSetResults.length,
      totalSets: _totalSets,
      totalRepetitions: totalRepetitions,
      totalHoldDuration: totalHoldDuration,
      startedAt: _startedAt,
      completedAt: _completedAt,
      exerciseAggregates: aggregates,
    );
  }

  void _validatePlan() {
    if (_plan.rounds <= 0) {
      throw ArgumentError.value(
        _plan.rounds,
        'plan.rounds',
        'Workout plan must contain at least one round.',
      );
    }
    if (_plan.exercises.isEmpty) {
      throw ArgumentError.value(
        _plan.exercises,
        'plan.exercises',
        'Workout plan must contain at least one exercise.',
      );
    }

    for (final block in _plan.exercises) {
      if (block.sets <= 0) {
        throw ArgumentError.value(
          block.sets,
          'block.sets',
          'Exercise blocks must contain at least one set.',
        );
      }
      if (block.restAfterSet.isNegative) {
        throw ArgumentError.value(
          block.restAfterSet,
          'block.restAfterSet',
          'Rest duration cannot be negative.',
        );
      }

      final definition = _exerciseCatalog.definitionFor(block.exercise);
      if (!definition.isAnalysisSupported) {
        throw ArgumentError.value(
          block.exercise,
          'block.exercise',
          'Workout engine requires an analysis-supported exercise.',
        );
      }

      switch (block.target.type) {
        case WorkoutTargetType.repetitions:
          final repetitions = block.target.repetitions;
          if (repetitions == null || repetitions <= 0) {
            throw ArgumentError.value(
              repetitions,
              'target.repetitions',
              'Repetition target must be greater than zero.',
            );
          }
          if (definition.trackingType != ExerciseTrackingType.repetitions) {
            throw ArgumentError(
              '${block.exercise.id} uses hold tracking and cannot use a '
              'repetition target.',
            );
          }
          break;
        case WorkoutTargetType.holdDuration:
          final holdDuration = block.target.holdDuration;
          if (holdDuration == null ||
              holdDuration.compareTo(Duration.zero) <= 0) {
            throw ArgumentError.value(
              holdDuration,
              'target.holdDuration',
              'Hold target must be greater than zero.',
            );
          }
          if (definition.trackingType != ExerciseTrackingType.hold) {
            throw ArgumentError(
              '${block.exercise.id} uses repetition tracking and cannot use a '
              'hold target.',
            );
          }
          break;
      }
    }
  }
}

class _MutableExerciseAggregate {
  _MutableExerciseAggregate(this.exercise);

  final ExerciseType exercise;
  int completedSets = 0;
  int totalRepetitions = 0;
  Duration totalHoldDuration = Duration.zero;
}
