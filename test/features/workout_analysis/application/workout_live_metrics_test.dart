import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_metric_registry.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/workout_live_metrics.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/workout_rep.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/workout_session.dart';

void main() {
  group('WorkoutSessionMetricSnapshotBuilder', () {
    const builder = WorkoutSessionMetricSnapshotBuilder();

    test(
      'builds repetition, average ROM, and tempo metrics from rep details',
      () {
        final session = WorkoutSession(
          id: 'session',
          ownerId: 'owner',
          exerciseType: 'squat',
          startedAt: DateTime.utc(2030, 1, 1),
          endedAt: DateTime.utc(2030, 1, 1, 0, 1),
          durationSec: 60,
          totalReps: 2,
          averageScore: 90,
          bestScore: 95,
          formWarningCount: 0,
          reps: const <WorkoutRep>[
            WorkoutRep(
              repIndex: 1,
              exerciseType: 'squat',
              analysisKind: 'rangeRep',
              primaryRom: 60,
              descentMillis: 600,
              ascentMillis: 400,
            ),
            WorkoutRep(
              repIndex: 2,
              exerciseType: 'squat',
              analysisKind: 'rangeRep',
              primaryRom: 80,
              descentMillis: 800,
              ascentMillis: 600,
            ),
          ],
        );

        final snapshot = builder.build(session);

        expect(snapshot.scope, ExerciseMetricScope.session);
        expect(snapshot.valueFor(ExerciseMetricRegistry.repetitionCount), 2);
        expect(snapshot.valueFor(ExerciseMetricRegistry.rangeOfMotion), 70);
        expect(
          snapshot.valueFor(ExerciseMetricRegistry.tempo),
          const Duration(milliseconds: 1200),
        );
        expect(
          snapshot.valueFor(ExerciseMetricRegistry.repDuration),
          const Duration(milliseconds: 1200),
        );
      },
    );

    test('builds hold duration without inventing repetition metrics', () {
      final session = WorkoutSession(
        id: 'hold',
        ownerId: 'owner',
        exerciseType: 'plank',
        analysisKind: 'hold',
        startedAt: DateTime.utc(2030, 1, 1),
        endedAt: DateTime.utc(2030, 1, 1, 0, 1),
        durationSec: 60,
        totalReps: 0,
        averageScore: 0,
        bestScore: 0,
        formWarningCount: 0,
        totalHoldSeconds: 42.5,
      );

      final snapshot = builder.build(session);

      expect(
        snapshot.valueFor(ExerciseMetricRegistry.holdDuration),
        const Duration(milliseconds: 42500),
      );
      expect(snapshot.valueFor(ExerciseMetricRegistry.repetitionCount), isNull);
    });
  });
}
