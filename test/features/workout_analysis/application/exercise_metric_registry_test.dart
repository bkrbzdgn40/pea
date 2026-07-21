import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_catalog.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_metric_registry.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_metrics.dart';

void main() {
  group('ExerciseMetricRegistry', () {
    test('registers exactly one definition for every canonical metric id', () {
      final definitions = ExerciseMetricRegistry.definitions;
      final registeredIds = definitions
          .map((definition) => definition.id)
          .toList(growable: false);
      final registeredKeys = definitions
          .map((definition) => definition.key)
          .toList(growable: false);

      expect(registeredIds, unorderedEquals(ExerciseMetricId.values));
      expect(registeredIds.toSet(), hasLength(ExerciseMetricId.values.length));
      expect(registeredKeys.toSet(), hasLength(registeredKeys.length));
    });

    test('exposes canonical type, family, unit, and scope contracts', () {
      expect(
        ExerciseMetricRegistry.repetitionCount.id,
        ExerciseMetricId.repetitionCount,
      );
      expect(
        ExerciseMetricRegistry.repetitionCount.family,
        ExerciseMetricFamily.repetition,
      );
      expect(
        ExerciseMetricRegistry.repetitionCount.unit,
        ExerciseMetricUnit.count,
      );
      expect(
        ExerciseMetricRegistry.repetitionCount.scopes,
        <ExerciseMetricScope>{ExerciseMetricScope.session},
      );

      expect(
        ExerciseMetricRegistry.primaryMovement.family,
        ExerciseMetricFamily.jointAngle,
      );
      expect(
        ExerciseMetricRegistry.primaryMovement.unit,
        ExerciseMetricUnit.degrees,
      );
      expect(
        ExerciseMetricRegistry.primaryMovement.supportsScope(
          ExerciseMetricScope.frame,
        ),
        isTrue,
      );

      expect(
        ExerciseMetricRegistry.rangeOfMotion.family,
        ExerciseMetricFamily.rangeOfMotion,
      );
      expect(ExerciseMetricRegistry.tempo.family, ExerciseMetricFamily.tempo);
      expect(
        ExerciseMetricRegistry.symmetry.family,
        ExerciseMetricFamily.symmetry,
      );
      expect(
        ExerciseMetricRegistry.stability.family,
        ExerciseMetricFamily.stability,
      );
      expect(
        ExerciseMetricRegistry.repDuration.family,
        ExerciseMetricFamily.duration,
      );
      expect(
        ExerciseMetricRegistry.holdDuration.family,
        ExerciseMetricFamily.duration,
      );
    });

    test('resolves definitions deterministically by id', () {
      for (final definition in ExerciseMetricRegistry.definitions) {
        expect(
          ExerciseMetricRegistry.definitionFor(definition.id),
          same(definition),
        );
        expect(ExerciseMetricRegistry.contains(definition.id), isTrue);
      }
    });

    test('preserves concrete value types in the heterogeneous registry', () {
      expect(ExerciseMetricRegistry.repetitionCount.valueType, int);
      expect(ExerciseMetricRegistry.holdDuration.valueType, Duration);
      expect(ExerciseMetricRegistry.primaryMovement.valueType, double);
      expect(ExerciseMetricRegistry.repDuration.valueType, Duration);

      expect(
        ExerciseMetricRegistry.definitionFor(
          ExerciseMetricId.repetitionCount,
        ).valueType,
        int,
      );
      expect(
        ExerciseMetricRegistry.definitionFor(
          ExerciseMetricId.primaryMovement,
        ).valueType,
        double,
      );
    });

    test('keeps every exercise metric declaration backed by the registry', () {
      const catalog = ExerciseCatalog();

      for (final exercise in catalog.definitions) {
        final resolvedIds = exercise.metricDefinitions
            .map((definition) => definition.id)
            .toSet();

        expect(resolvedIds, exercise.metricIds, reason: exercise.id);
        for (final metricId in exercise.metricIds) {
          expect(
            ExerciseMetricRegistry.contains(metricId),
            isTrue,
            reason: '${exercise.id}:${metricId.name}',
          );
        }
      }
    });
  });

  group('ExerciseMetricSnapshot', () {
    test('stores and reads heterogeneous values through typed definitions', () {
      final builder =
          ExerciseMetricSnapshotBuilder(scope: ExerciseMetricScope.repetition)
            ..set(ExerciseMetricRegistry.primaryMovement, 92.5)
            ..set(ExerciseMetricRegistry.rangeOfMotion, 67.0)
            ..set(
              ExerciseMetricRegistry.repDuration,
              const Duration(milliseconds: 1600),
            );

      final snapshot = builder.build();

      expect(snapshot.scope, ExerciseMetricScope.repetition);
      expect(snapshot.valueFor(ExerciseMetricRegistry.primaryMovement), 92.5);
      expect(snapshot.valueFor(ExerciseMetricRegistry.rangeOfMotion), 67.0);
      expect(
        snapshot.valueFor(ExerciseMetricRegistry.repDuration),
        const Duration(milliseconds: 1600),
      );
      expect(snapshot.valueFor(ExerciseMetricRegistry.tempo), isNull);
    });

    test('rejects metrics that are not valid for the target scope', () {
      final builder = ExerciseMetricSnapshotBuilder(
        scope: ExerciseMetricScope.frame,
      );

      expect(
        () => builder.set(ExerciseMetricRegistry.repetitionCount, 1),
        throwsA(isA<StateError>()),
      );
    });

    test('rejects metric values created for another scope', () {
      final builder = ExerciseMetricSnapshotBuilder(
        scope: ExerciseMetricScope.session,
      );
      const metricValue = ExerciseMetricValue<double>(
        definition: ExerciseMetricRegistry.primaryMovement,
        value: 90.0,
        scope: ExerciseMetricScope.repetition,
      );

      expect(() => builder.add(metricValue), throwsA(isA<StateError>()));
    });

    test('exposes an immutable metric id collection', () {
      final snapshot = (ExerciseMetricSnapshotBuilder(
        scope: ExerciseMetricScope.session,
      )..set(ExerciseMetricRegistry.repetitionCount, 10)).build();

      expect(
        () => snapshot.metricIds.add(ExerciseMetricId.form),
        throwsUnsupportedError,
      );
    });
  });

  group('ExerciseMetrics.frameMetricSnapshot', () {
    test(
      'bridges current extractor metrics into the canonical frame model',
      () {
        final metrics = const ExerciseMetrics.noPose().copyWith(
          primaryAngle: 88.0,
          formMetric: 162.0,
          hasPrimaryAngle: true,
          hasFormMetric: true,
        );

        final snapshot = metrics.frameMetricSnapshot;

        expect(snapshot.scope, ExerciseMetricScope.frame);
        expect(snapshot.valueFor(ExerciseMetricRegistry.primaryMovement), 88.0);
        expect(snapshot.valueFor(ExerciseMetricRegistry.form), 162.0);
      },
    );

    test('does not invent unavailable frame metrics', () {
      final snapshot = const ExerciseMetrics.noPose().frameMetricSnapshot;

      expect(snapshot.isEmpty, isTrue);
      expect(snapshot.valueFor(ExerciseMetricRegistry.primaryMovement), isNull);
      expect(snapshot.valueFor(ExerciseMetricRegistry.form), isNull);
    });
  });
}
