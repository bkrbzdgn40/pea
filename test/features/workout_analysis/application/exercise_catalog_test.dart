import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/engine_kind.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_catalog.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_type.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/hold_contract.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/range_rep_contract.dart';

void main() {
  const catalog = ExerciseCatalog();

  group('ExerciseCatalog', () {
    test('marks push-up as a supported range-rep exercise', () {
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

    test('marks plank as a supported hold exercise', () {
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

    test('keeps lunge and sit-up unsupported', () {
      for (final exercise in const [ExerciseType.lunge, ExerciseType.sitUp]) {
        final definition = catalog.definitionFor(exercise);
        expect(definition.isAnalysisSupported, isFalse);
      }
    });
  });
}
