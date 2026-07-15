import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/engine_kind.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_catalog.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_type.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_contract.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/range_rep_contract.dart';

void main() {
  const catalog = ExerciseCatalog();

  group('ExerciseCatalog', () {
    test(
      'registers exactly one analysis definition per canonical exercise',
      () {
        final registeredTypes = catalog.definitions
            .map((definition) => definition.type)
            .toList(growable: false);

        expect(registeredTypes, unorderedEquals(ExerciseType.values));
        expect(registeredTypes.toSet(), hasLength(ExerciseType.values.length));
      },
    );

    test('derives id and title from the canonical exercise identity', () {
      for (final type in ExerciseType.values) {
        final definition = catalog.definitionFor(type);

        expect(definition.type, type);
        expect(definition.id, type.id);
        expect(definition.title, type.title);
      }
    });

    test(
      'definitionFor and definitionForIdOrNull resolve deterministically',
      () {
        for (final type in ExerciseType.values) {
          final byType = catalog.definitionFor(type);
          final byId = catalog.definitionForIdOrNull(type.id);

          expect(byId, same(byType));
        }
      },
    );

    test('keeps squat as a supported range-rep exercise', () {
      final definition = catalog.definitionFor(ExerciseType.squat);

      expect(definition.isAnalysisSupported, isTrue);
      expect(definition.analysisExercise, ExerciseType.squat);
      expect(definition.analysisEngineKind, EngineKind.rangeRep);
      expect(
        definition.analysisConfigAssetPath,
        'assets/config/exercises/squat.json',
      );
      expect(
        definition.analysisRangeRepContract,
        same(RangeRepContracts.squat),
      );
    });

    test('keeps plank as a supported hold exercise', () {
      final definition = catalog.definitionFor(ExerciseType.plank);

      expect(definition.isAnalysisSupported, isTrue);
      expect(definition.analysisExercise, ExerciseType.plank);
      expect(definition.analysisEngineKind, EngineKind.hold);
      expect(
        definition.analysisConfigAssetPath,
        'assets/config/exercises/plank.json',
      );
      expect(definition.analysisHoldContract, same(HoldContracts.plankFamily));
    });

    test('keeps push-up as a supported range-rep exercise', () {
      final definition = catalog.definitionFor(ExerciseType.pushUp);

      expect(definition.isAnalysisSupported, isTrue);
      expect(definition.analysisExercise, ExerciseType.pushUp);
      expect(definition.analysisEngineKind, EngineKind.rangeRep);
      expect(
        definition.analysisConfigAssetPath,
        'assets/config/exercises/push_up.json',
      );
      expect(
        definition.analysisRangeRepContract,
        same(RangeRepContracts.pushUp),
      );
    });

    test('keeps lunge and sit-up unsupported', () {
      for (final type in const <ExerciseType>[
        ExerciseType.lunge,
        ExerciseType.sitUp,
      ]) {
        final definition = catalog.definitionFor(type);

        expect(definition.id, type.id);
        expect(definition.title, type.title);
        expect(definition.isAnalysisSupported, isFalse);
      }
    });
  });
}
