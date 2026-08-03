import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/workout_engine.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_type.dart';

void main() {
  group('WorkoutEngine', () {
    test('starts at the first exercise, set, and round', () {
      final clock = _MutableClock(DateTime.utc(2030, 1, 1, 12));
      final engine = WorkoutEngine(
        plan: WorkoutPlan(
          rounds: 2,
          exercises: const <WorkoutExerciseBlock>[
            WorkoutExerciseBlock(
              exercise: ExerciseType.squat,
              target: WorkoutTarget.repetitions(10),
              sets: 3,
            ),
            WorkoutExerciseBlock(
              exercise: ExerciseType.plank,
              target: WorkoutTarget.hold(Duration(seconds: 30)),
            ),
          ],
        ),
        clock: clock.now,
      );

      final state = engine.start();

      expect(state.phase, WorkoutEnginePhase.active);
      expect(state.currentExercise, ExerciseType.squat);
      expect(state.roundNumber, 1);
      expect(state.totalRounds, 2);
      expect(state.exerciseIndex, 1);
      expect(state.exerciseCount, 2);
      expect(state.setNumber, 1);
      expect(state.setsInCurrentExercise, 3);
      expect(state.completedSets, 0);
      expect(state.totalSets, 8);
      expect(state.startedAt, DateTime.utc(2030, 1, 1, 12));
      expect(state.progress, 0);
    });

    test('rep target completes once and waits for explicit advance', () {
      final engine = WorkoutEngine(
        plan: WorkoutPlan(
          exercises: const <WorkoutExerciseBlock>[
            WorkoutExerciseBlock(
              exercise: ExerciseType.squat,
              target: WorkoutTarget.repetitions(3),
            ),
          ],
        ),
      )..start();

      var state = engine.observe(
        const WorkoutProgressObservation.repetitions(
          exercise: ExerciseType.squat,
          cumulativeRepCount: 2,
        ),
      );
      expect(state.phase, WorkoutEnginePhase.active);
      expect(state.currentRepetitions, 2);
      expect(state.progress, closeTo(2 / 3, 0.001));

      state = engine.observe(
        const WorkoutProgressObservation.repetitions(
          exercise: ExerciseType.squat,
          cumulativeRepCount: 3,
        ),
      );
      expect(state.phase, WorkoutEnginePhase.setCompleted);
      expect(state.completedSets, 1);
      expect(state.completedSetResults, hasLength(1));
      expect(state.completedSetResults.single.repetitions, 3);

      state = engine.observe(
        const WorkoutProgressObservation.repetitions(
          exercise: ExerciseType.squat,
          cumulativeRepCount: 4,
        ),
      );
      expect(state.completedSets, 1);
      expect(state.completedSetResults, hasLength(1));
      expect(state.currentRepetitions, 3);
    });

    test('same-exercise sets use cumulative rep count as a baseline', () {
      final engine = WorkoutEngine(
        plan: WorkoutPlan(
          exercises: const <WorkoutExerciseBlock>[
            WorkoutExerciseBlock(
              exercise: ExerciseType.squat,
              target: WorkoutTarget.repetitions(2),
              sets: 2,
            ),
          ],
        ),
      )..start();

      engine.observe(
        const WorkoutProgressObservation.repetitions(
          exercise: ExerciseType.squat,
          cumulativeRepCount: 2,
        ),
      );
      var state = engine.advance();
      expect(state.currentExercise, ExerciseType.squat);
      expect(state.setNumber, 2);
      expect(state.currentRepetitions, 0);

      state = engine.observe(
        const WorkoutProgressObservation.repetitions(
          exercise: ExerciseType.squat,
          cumulativeRepCount: 3,
        ),
      );
      expect(state.phase, WorkoutEnginePhase.active);
      expect(state.currentRepetitions, 1);

      state = engine.observe(
        const WorkoutProgressObservation.repetitions(
          exercise: ExerciseType.squat,
          cumulativeRepCount: 4,
        ),
      );
      expect(state.phase, WorkoutEnginePhase.setCompleted);
      expect(state.completedSets, 2);
    });

    test('rebases the next set after movement during rest', () {
      final engine = WorkoutEngine(
        plan: WorkoutPlan(
          exercises: const <WorkoutExerciseBlock>[
            WorkoutExerciseBlock(
              exercise: ExerciseType.squat,
              target: WorkoutTarget.repetitions(2),
              sets: 2,
            ),
          ],
        ),
      )..start();

      engine.observe(
        const WorkoutProgressObservation.repetitions(
          exercise: ExerciseType.squat,
          cumulativeRepCount: 2,
        ),
      );
      var state = engine.advance(repetitionBaseline: 5);
      expect(state.currentRepetitions, 0);

      state = engine.observe(
        const WorkoutProgressObservation.repetitions(
          exercise: ExerciseType.squat,
          cumulativeRepCount: 5,
        ),
      );
      expect(state.currentRepetitions, 0);

      state = engine.observe(
        const WorkoutProgressObservation.repetitions(
          exercise: ExerciseType.squat,
          cumulativeRepCount: 6,
        ),
      );
      expect(state.currentRepetitions, 1);
      expect(state.isSetCompleted, isFalse);
    });

    test('rebases the next hold set after holding during rest', () {
      final engine = WorkoutEngine(
        plan: WorkoutPlan(
          exercises: const <WorkoutExerciseBlock>[
            WorkoutExerciseBlock(
              exercise: ExerciseType.plank,
              target: WorkoutTarget.hold(Duration(seconds: 10)),
              sets: 2,
            ),
          ],
        ),
      )..start();

      engine.observe(
        const WorkoutProgressObservation.hold(
          exercise: ExerciseType.plank,
          currentHoldDuration: Duration(seconds: 10),
        ),
      );
      var state = engine.advance(holdBaseline: const Duration(seconds: 14));
      expect(state.currentHoldDuration, Duration.zero);

      state = engine.observe(
        const WorkoutProgressObservation.hold(
          exercise: ExerciseType.plank,
          currentHoldDuration: Duration(seconds: 14),
        ),
      );
      expect(state.currentHoldDuration, Duration.zero);

      state = engine.observe(
        const WorkoutProgressObservation.hold(
          exercise: ExerciseType.plank,
          currentHoldDuration: Duration(seconds: 15),
        ),
      );
      expect(state.currentHoldDuration, const Duration(seconds: 1));
      expect(state.isSetCompleted, isFalse);
    });

    test('rep counter reset is accepted within a same-exercise workout', () {
      final engine = WorkoutEngine(
        plan: WorkoutPlan(
          exercises: const <WorkoutExerciseBlock>[
            WorkoutExerciseBlock(
              exercise: ExerciseType.squat,
              target: WorkoutTarget.repetitions(2),
              sets: 2,
            ),
          ],
        ),
      )..start();

      engine.observe(
        const WorkoutProgressObservation.repetitions(
          exercise: ExerciseType.squat,
          cumulativeRepCount: 2,
        ),
      );
      engine.advance();

      final state = engine.observe(
        const WorkoutProgressObservation.repetitions(
          exercise: ExerciseType.squat,
          cumulativeRepCount: 1,
        ),
      );

      expect(state.phase, WorkoutEnginePhase.active);
      expect(state.currentRepetitions, 1);
    });

    test('hold target completes from current hold duration', () {
      final engine = WorkoutEngine(
        plan: WorkoutPlan(
          exercises: const <WorkoutExerciseBlock>[
            WorkoutExerciseBlock(
              exercise: ExerciseType.wallSit,
              target: WorkoutTarget.hold(Duration(seconds: 30)),
            ),
          ],
        ),
      )..start();

      var state = engine.observe(
        const WorkoutProgressObservation.hold(
          exercise: ExerciseType.wallSit,
          currentHoldDuration: Duration(seconds: 18),
        ),
      );
      expect(state.phase, WorkoutEnginePhase.active);
      expect(state.currentHoldDuration, const Duration(seconds: 18));
      expect(state.progress, closeTo(0.6, 0.001));

      state = engine.observe(
        const WorkoutProgressObservation.hold(
          exercise: ExerciseType.wallSit,
          currentHoldDuration: Duration(seconds: 30),
        ),
      );
      expect(state.phase, WorkoutEnginePhase.setCompleted);
      expect(
        state.completedSetResults.single.holdDuration,
        const Duration(seconds: 30),
      );
    });

    test('hold reset starts a fresh baseline for the next set', () {
      final engine = WorkoutEngine(
        plan: WorkoutPlan(
          exercises: const <WorkoutExerciseBlock>[
            WorkoutExerciseBlock(
              exercise: ExerciseType.plank,
              target: WorkoutTarget.hold(Duration(seconds: 10)),
              sets: 2,
            ),
          ],
        ),
      )..start();

      engine.observe(
        const WorkoutProgressObservation.hold(
          exercise: ExerciseType.plank,
          currentHoldDuration: Duration(seconds: 10),
        ),
      );
      engine.advance();

      var state = engine.observe(
        const WorkoutProgressObservation.hold(
          exercise: ExerciseType.plank,
          currentHoldDuration: Duration(seconds: 2),
        ),
      );
      expect(state.currentHoldDuration, const Duration(seconds: 2));
      expect(state.phase, WorkoutEnginePhase.active);

      state = engine.observe(
        const WorkoutProgressObservation.hold(
          exercise: ExerciseType.plank,
          currentHoldDuration: Duration(seconds: 10),
        ),
      );
      expect(state.phase, WorkoutEnginePhase.setCompleted);
      expect(state.completedSets, 2);
    });

    test('advances across exercises and rounds deterministically', () {
      final engine = WorkoutEngine(
        plan: WorkoutPlan(
          rounds: 2,
          exercises: const <WorkoutExerciseBlock>[
            WorkoutExerciseBlock(
              exercise: ExerciseType.squat,
              target: WorkoutTarget.repetitions(1),
            ),
            WorkoutExerciseBlock(
              exercise: ExerciseType.plank,
              target: WorkoutTarget.hold(Duration(seconds: 1)),
            ),
          ],
        ),
      )..start();

      engine.observe(
        const WorkoutProgressObservation.repetitions(
          exercise: ExerciseType.squat,
          cumulativeRepCount: 1,
        ),
      );
      var state = engine.advance();
      expect(state.currentExercise, ExerciseType.plank);
      expect(state.roundNumber, 1);
      expect(state.exerciseIndex, 2);

      engine.observe(
        const WorkoutProgressObservation.hold(
          exercise: ExerciseType.plank,
          currentHoldDuration: Duration(seconds: 1),
        ),
      );
      state = engine.advance();
      expect(state.currentExercise, ExerciseType.squat);
      expect(state.roundNumber, 2);
      expect(state.exerciseIndex, 1);

      engine.observe(
        const WorkoutProgressObservation.repetitions(
          exercise: ExerciseType.squat,
          cumulativeRepCount: 1,
        ),
      );
      state = engine.advance();
      expect(state.currentExercise, ExerciseType.plank);
      expect(state.roundNumber, 2);

      engine.observe(
        const WorkoutProgressObservation.hold(
          exercise: ExerciseType.plank,
          currentHoldDuration: Duration(seconds: 1),
        ),
      );
      state = engine.advance();
      expect(state.phase, WorkoutEnginePhase.completed);
      expect(state.currentExercise, isNull);
      expect(state.completedSets, 4);
    });

    test('summary aggregates repetitions and hold duration per exercise', () {
      final clock = _MutableClock(DateTime.utc(2030, 1, 1, 12));
      final engine = WorkoutEngine(
        plan: WorkoutPlan(
          exercises: const <WorkoutExerciseBlock>[
            WorkoutExerciseBlock(
              exercise: ExerciseType.squat,
              target: WorkoutTarget.repetitions(2),
            ),
            WorkoutExerciseBlock(
              exercise: ExerciseType.wallSit,
              target: WorkoutTarget.hold(Duration(seconds: 15)),
            ),
          ],
        ),
        clock: clock.now,
      )..start();

      clock.advance(const Duration(seconds: 5));
      engine.observe(
        const WorkoutProgressObservation.repetitions(
          exercise: ExerciseType.squat,
          cumulativeRepCount: 2,
        ),
      );
      engine.advance();

      clock.advance(const Duration(seconds: 20));
      engine.observe(
        const WorkoutProgressObservation.hold(
          exercise: ExerciseType.wallSit,
          currentHoldDuration: Duration(seconds: 15),
        ),
      );
      clock.advance(const Duration(seconds: 1));
      final state = engine.advance();

      expect(state.phase, WorkoutEnginePhase.completed);
      expect(state.summary.completedSets, 2);
      expect(state.summary.totalSets, 2);
      expect(state.summary.totalRepetitions, 2);
      expect(state.summary.totalHoldDuration, const Duration(seconds: 15));
      expect(state.summary.exerciseAggregates, hasLength(2));
      expect(
        state.summary.exerciseAggregates[ExerciseType.squat]!.totalRepetitions,
        2,
      );
      expect(
        state
            .summary
            .exerciseAggregates[ExerciseType.wallSit]!
            .totalHoldDuration,
        const Duration(seconds: 15),
      );
      expect(state.summary.elapsed, const Duration(seconds: 26));
    });

    test('rejects progress for an exercise that is not active', () {
      final engine = WorkoutEngine(
        plan: WorkoutPlan(
          exercises: const <WorkoutExerciseBlock>[
            WorkoutExerciseBlock(
              exercise: ExerciseType.squat,
              target: WorkoutTarget.repetitions(5),
            ),
          ],
        ),
      )..start();

      expect(
        () => engine.observe(
          const WorkoutProgressObservation.repetitions(
            exercise: ExerciseType.pushUp,
            cumulativeRepCount: 1,
          ),
        ),
        throwsArgumentError,
      );
    });

    test('rejects progress observation type mismatches', () {
      final engine = WorkoutEngine(
        plan: WorkoutPlan(
          exercises: const <WorkoutExerciseBlock>[
            WorkoutExerciseBlock(
              exercise: ExerciseType.squat,
              target: WorkoutTarget.repetitions(5),
            ),
          ],
        ),
      )..start();

      expect(
        () => engine.observe(
          const WorkoutProgressObservation.hold(
            exercise: ExerciseType.squat,
            currentHoldDuration: Duration(seconds: 5),
          ),
        ),
        throwsArgumentError,
      );
    });

    test('cannot advance before the current set is completed', () {
      final engine = WorkoutEngine(
        plan: WorkoutPlan(
          exercises: const <WorkoutExerciseBlock>[
            WorkoutExerciseBlock(
              exercise: ExerciseType.squat,
              target: WorkoutTarget.repetitions(5),
            ),
          ],
        ),
      )..start();

      expect(engine.advance, throwsStateError);
    });

    test('rejects target types that do not match exercise tracking', () {
      expect(
        () => WorkoutEngine(
          plan: WorkoutPlan(
            exercises: const <WorkoutExerciseBlock>[
              WorkoutExerciseBlock(
                exercise: ExerciseType.plank,
                target: WorkoutTarget.repetitions(10),
              ),
            ],
          ),
        ),
        throwsArgumentError,
      );
      expect(
        () => WorkoutEngine(
          plan: WorkoutPlan(
            exercises: const <WorkoutExerciseBlock>[
              WorkoutExerciseBlock(
                exercise: ExerciseType.squat,
                target: WorkoutTarget.hold(Duration(seconds: 20)),
              ),
            ],
          ),
        ),
        throwsArgumentError,
      );
    });

    test('rejects empty or non-positive workout plans', () {
      expect(
        () => WorkoutEngine(
          plan: WorkoutPlan(exercises: const <WorkoutExerciseBlock>[]),
        ),
        throwsArgumentError,
      );
      expect(
        () => WorkoutEngine(
          plan: WorkoutPlan(
            rounds: 0,
            exercises: const <WorkoutExerciseBlock>[
              WorkoutExerciseBlock(
                exercise: ExerciseType.squat,
                target: WorkoutTarget.repetitions(1),
              ),
            ],
          ),
        ),
        throwsArgumentError,
      );
      expect(
        () => WorkoutEngine(
          plan: WorkoutPlan(
            exercises: const <WorkoutExerciseBlock>[
              WorkoutExerciseBlock(
                exercise: ExerciseType.squat,
                target: WorkoutTarget.repetitions(1),
                sets: 0,
              ),
            ],
          ),
        ),
        throwsArgumentError,
      );
    });

    test('preserves duplicate exercise blocks in the configured order', () {
      final engine = WorkoutEngine(
        plan: WorkoutPlan(
          name: 'Duplicate order',
          exercises: const <WorkoutExerciseBlock>[
            WorkoutExerciseBlock(
              exercise: ExerciseType.squat,
              target: WorkoutTarget.repetitions(1),
              restAfterSet: Duration(seconds: 15),
            ),
            WorkoutExerciseBlock(
              exercise: ExerciseType.plank,
              target: WorkoutTarget.hold(Duration(seconds: 1)),
              restAfterSet: Duration(seconds: 30),
            ),
            WorkoutExerciseBlock(
              exercise: ExerciseType.squat,
              target: WorkoutTarget.repetitions(2),
              restAfterSet: Duration(seconds: 45),
            ),
          ],
        ),
      );

      var snapshot = engine.start();
      expect(snapshot.currentExercise, ExerciseType.squat);
      expect(snapshot.restAfterSet, const Duration(seconds: 15));

      snapshot = engine.observe(
        const WorkoutProgressObservation.repetitions(
          exercise: ExerciseType.squat,
          cumulativeRepCount: 1,
        ),
      );
      expect(snapshot.isSetCompleted, isTrue);
      snapshot = engine.advance();
      expect(snapshot.currentExercise, ExerciseType.plank);
      expect(snapshot.restAfterSet, const Duration(seconds: 30));

      snapshot = engine.observe(
        const WorkoutProgressObservation.hold(
          exercise: ExerciseType.plank,
          currentHoldDuration: Duration(seconds: 1),
        ),
      );
      expect(snapshot.isSetCompleted, isTrue);
      snapshot = engine.advance();
      expect(snapshot.currentExercise, ExerciseType.squat);
      expect(snapshot.targetRepetitions, 2);
      expect(snapshot.restAfterSet, const Duration(seconds: 45));
    });

    test('rejects negative rest durations', () {
      expect(
        () => WorkoutEngine(
          plan: WorkoutPlan(
            exercises: const <WorkoutExerciseBlock>[
              WorkoutExerciseBlock(
                exercise: ExerciseType.squat,
                target: WorkoutTarget.repetitions(1),
                restAfterSet: Duration(seconds: -1),
              ),
            ],
          ),
        ),
        throwsArgumentError,
      );
    });

    test('rejects rest durations above the plan maximum', () {
      expect(
        () => WorkoutEngine(
          plan: WorkoutPlan(
            exercises: const <WorkoutExerciseBlock>[
              WorkoutExerciseBlock(
                exercise: ExerciseType.squat,
                target: WorkoutTarget.repetitions(5),
                restAfterSet: Duration(seconds: 61),
              ),
            ],
          ),
        ),
        throwsArgumentError,
      );
    });

    test('reset clears progress and allows a fresh start', () {
      final engine = WorkoutEngine(
        plan: WorkoutPlan(
          exercises: const <WorkoutExerciseBlock>[
            WorkoutExerciseBlock(
              exercise: ExerciseType.squat,
              target: WorkoutTarget.repetitions(1),
            ),
          ],
        ),
      )..start();

      engine.observe(
        const WorkoutProgressObservation.repetitions(
          exercise: ExerciseType.squat,
          cumulativeRepCount: 1,
        ),
      );
      var state = engine.reset();
      expect(state.phase, WorkoutEnginePhase.idle);
      expect(state.completedSets, 0);
      expect(state.completedSetResults, isEmpty);
      expect(state.startedAt, isNull);

      state = engine.start();
      expect(state.phase, WorkoutEnginePhase.active);
      expect(state.currentExercise, ExerciseType.squat);
    });
  });
}

class _MutableClock {
  _MutableClock(this._now);

  DateTime _now;

  DateTime now() => _now;

  void advance(Duration duration) {
    _now = _now.add(duration);
  }
}
