import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_catalog.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_type.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/data/exercise_guide_catalog.dart';

void main() {
  const analysisCatalog = ExerciseCatalog();
  const guideCatalog = ExerciseGuideCatalog();

  group('ExerciseGuideCatalog', () {
    test(
      'preserves the guide entries with unique canonical exercise types',
      () {
        final types = guideCatalog.contents
            .map((content) => content.type)
            .toList(growable: false);

        expect(guideCatalog.contents, hasLength(6));
        expect(types.toSet(), hasLength(6));
        expect(types, unorderedEquals(ExerciseType.values));
      },
    );

    test('derives guide id and title from the canonical exercise identity', () {
      for (final content in guideCatalog.contents) {
        expect(content.id, content.type.id);
        expect(content.title, content.type.title);
        expect(guideCatalog.contentFor(content.type), same(content));
      }
    });

    test('resolves guide entries through the canonical id path', () {
      for (final type in ExerciseType.values) {
        final content = guideCatalog.contentForIdOrNull(type.id);

        expect(content, isNotNull);
        expect(content!.type, type);
      }

      expect(guideCatalog.contentForIdOrNull('burpee'), isNull);
    });

    test('guide content stays independent from analysis support policy', () {
      final lungeDefinition = analysisCatalog.definitionFor(ExerciseType.lunge);
      final lungeContent = guideCatalog.contentFor(ExerciseType.lunge);
      final sitUpDefinition = analysisCatalog.definitionFor(ExerciseType.sitUp);
      final sitUpContent = guideCatalog.contentFor(ExerciseType.sitUp);

      expect(lungeDefinition.isAnalysisSupported, isFalse);
      expect(lungeContent.type, ExerciseType.lunge);
      expect(lungeContent.subtitle, isNotEmpty);

      expect(sitUpDefinition.isAnalysisSupported, isTrue);
      expect(sitUpDefinition.analysisEngineKind.name, 'rangeRep');
      expect(sitUpContent.type, ExerciseType.sitUp);
      expect(sitUpContent.subtitle, isNotEmpty);
    });

    test(
      'biceps curl guide stays on the canonical owner with bilateral coaching',
      () {
        final bicepsDefinition = analysisCatalog.definitionFor(
          ExerciseType.bicepsCurl,
        );
        final bicepsContent = guideCatalog.contentFor(ExerciseType.bicepsCurl);

        expect(bicepsDefinition.isAnalysisSupported, isTrue);
        expect(bicepsDefinition.analysisEngineKind.name, 'rangeRep');
        expect(bicepsContent.type, ExerciseType.bicepsCurl);
        expect(
          bicepsContent.setupSteps.join(' '),
          contains('30-45 derece çapraz açıyla'),
        );
        expect(
          bicepsContent.tips.join(' '),
          contains('Dirseklerini gövdeye yakın ve sabit tut.'),
        );
      },
    );
  });
}
