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

    test('enables sit-up as a supported range-rep exercise', () {
      final definition = catalog.definitionFor(ExerciseType.sitUp);

      expect(definition.isAnalysisSupported, isTrue);
      expect(definition.analysisExercise, ExerciseType.sitUp);
      expect(definition.analysisEngineKind, EngineKind.rangeRep);
      expect(
        definition.analysisConfigAssetPath,
        'assets/config/exercises/sit_up.json',
      );
      expect(
        definition.analysisRangeRepContract,
        same(RangeRepContracts.sitUp),
      );
    });

    test('enables biceps curl as a supported bilateral range-rep exercise', () {
      final definition = catalog.definitionFor(ExerciseType.bicepsCurl);

      expect(definition.isAnalysisSupported, isTrue);
      expect(definition.analysisExercise, ExerciseType.bicepsCurl);
      expect(definition.analysisEngineKind, EngineKind.rangeRep);
      expect(
        definition.analysisConfigAssetPath,
        'assets/config/exercises/biceps_curl.json',
      );
      expect(
        definition.analysisRangeRepContract,
        same(RangeRepContracts.bicepsCurl),
      );
      expect(
        definition.analysisRangeRepContract.sideMode,
        RangeRepSideMode.bilateral,
      );
    });

    test('keeps lunge unsupported', () {
      final definition = catalog.definitionFor(ExerciseType.lunge);

      expect(definition.id, ExerciseType.lunge.id);
      expect(definition.title, ExerciseType.lunge.title);
      expect(definition.isAnalysisSupported, isFalse);
    });
  });
}
