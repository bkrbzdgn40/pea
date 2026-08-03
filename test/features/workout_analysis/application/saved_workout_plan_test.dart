import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/saved_workout_plan.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/workout_engine.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_type.dart';

void main() {
  test('round-trips ordered duplicate entries and editable targets', () {
    final plan = SavedWorkoutPlan(
      id: 'plan-1',
      name: 'Bacak Günü',
      rounds: 2,
      updatedAt: DateTime.utc(2026, 7, 30),
      entries: const [
        SavedWorkoutPlanEntry(
          id: 'entry-1',
          exercise: ExerciseType.squat,
          sets: 3,
          target: WorkoutTarget.repetitions(12),
          restAfterSet: Duration(seconds: 45),
        ),
        SavedWorkoutPlanEntry(
          id: 'entry-2',
          exercise: ExerciseType.plank,
          sets: 2,
          target: WorkoutTarget.hold(Duration(seconds: 40)),
          restAfterSet: Duration(seconds: 30),
        ),
        SavedWorkoutPlanEntry(
          id: 'entry-3',
          exercise: ExerciseType.squat,
          sets: 1,
          target: WorkoutTarget.repetitions(8),
          restAfterSet: Duration(seconds: 60),
        ),
      ],
    );

    final decoded = SavedWorkoutPlan.fromJson(plan.toJson());

    expect(decoded, isNotNull);
    expect(decoded!.name, 'Bacak Günü');
    expect(decoded.rounds, 2);
    expect(decoded.entries.map((entry) => entry.exercise), [
      ExerciseType.squat,
      ExerciseType.plank,
      ExerciseType.squat,
    ]);
    expect(decoded.entries[0].sets, 3);
    expect(decoded.entries[0].target.repetitions, 12);
    expect(decoded.entries[1].target.holdDuration, const Duration(seconds: 40));
    expect(decoded.entries[2].restAfterSet, const Duration(seconds: 60));
  });

  test(
    'converts saved plan to engine plan without losing order or duplicates',
    () {
      final plan = SavedWorkoutPlan(
        id: 'plan-2',
        name: 'Tekrarlar',
        rounds: 1,
        updatedAt: DateTime.utc(2026, 7, 30),
        entries: const [
          SavedWorkoutPlanEntry(
            id: 'first',
            exercise: ExerciseType.bicepsCurl,
            sets: 2,
            target: WorkoutTarget.repetitions(10),
            restAfterSet: Duration(seconds: 30),
          ),
          SavedWorkoutPlanEntry(
            id: 'second',
            exercise: ExerciseType.shoulderPress,
            sets: 3,
            target: WorkoutTarget.repetitions(8),
            restAfterSet: Duration(seconds: 45),
          ),
          SavedWorkoutPlanEntry(
            id: 'third',
            exercise: ExerciseType.bicepsCurl,
            sets: 1,
            target: WorkoutTarget.repetitions(6),
            restAfterSet: Duration(seconds: 15),
          ),
        ],
      );

      final enginePlan = plan.toWorkoutPlan();

      expect(enginePlan.id, 'plan-2');
      expect(enginePlan.name, 'Tekrarlar');
      expect(enginePlan.exercises.map((block) => block.exercise), [
        ExerciseType.bicepsCurl,
        ExerciseType.shoulderPress,
        ExerciseType.bicepsCurl,
      ]);
      expect(enginePlan.exercises[1].sets, 3);
      expect(enginePlan.exercises[1].restAfterSet, const Duration(seconds: 45));
    },
  );

  test(
    'calculates total sets and rest without adding rest after final set',
    () {
      final plan = SavedWorkoutPlan(
        id: 'plan-3',
        name: 'Kısa Plan',
        rounds: 2,
        updatedAt: DateTime.utc(2026, 7, 30),
        entries: const [
          SavedWorkoutPlanEntry(
            id: 'a',
            exercise: ExerciseType.squat,
            sets: 2,
            target: WorkoutTarget.repetitions(10),
            restAfterSet: Duration(seconds: 30),
          ),
          SavedWorkoutPlanEntry(
            id: 'b',
            exercise: ExerciseType.plank,
            sets: 1,
            target: WorkoutTarget.hold(Duration(seconds: 20)),
            restAfterSet: Duration(seconds: 45),
          ),
        ],
      );

      expect(plan.totalSets, 6);
      expect(plan.estimatedRestDuration, const Duration(seconds: 165));
    },
  );

  test('normalizes rest duration to the sixty-second plan limit', () {
    final plan = SavedWorkoutPlan(
      id: 'rest-limit',
      name: 'Rest Limit',
      rounds: 1,
      updatedAt: DateTime.utc(2026, 8, 3),
      entries: const <SavedWorkoutPlanEntry>[
        SavedWorkoutPlanEntry(
          id: 'entry-1',
          exercise: ExerciseType.squat,
          sets: 1,
          target: WorkoutTarget.repetitions(10),
          restAfterSet: Duration(seconds: 95),
        ),
      ],
    );

    expect(plan.entries.single.restAfterSet, maxWorkoutPlanRestDuration);
    expect(
      plan.toWorkoutPlan().exercises.single.restAfterSet,
      maxWorkoutPlanRestDuration,
    );
    final encodedEntries = plan.toJson()['entries']! as List<Object?>;
    final encodedEntry = encodedEntries.single! as Map<String, Object?>;
    expect(encodedEntry['restSeconds'], 60);

    final decoded = SavedWorkoutPlan.fromJson(<String, Object?>{
      'id': 'decoded-rest-limit',
      'name': 'Decoded Rest Limit',
      'rounds': 1,
      'updatedAt': DateTime.utc(2026, 8, 3).toIso8601String(),
      'entries': <Map<String, Object?>>[
        <String, Object?>{
          'id': 'entry-1',
          'exercise': ExerciseType.squat.id,
          'sets': 1,
          'targetType': 'repetitions',
          'targetValue': 10,
          'restSeconds': 120,
        },
      ],
    });

    expect(decoded, isNotNull);
    expect(decoded!.entries.single.restAfterSet, maxWorkoutPlanRestDuration);
  });
}
