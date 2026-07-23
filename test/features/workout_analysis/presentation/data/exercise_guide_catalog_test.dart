import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_catalog.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/camera_view_contract.dart';
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

        expect(guideCatalog.contents, hasLength(ExerciseType.values.length));
        expect(types.toSet(), hasLength(ExerciseType.values.length));
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

      expect(lungeDefinition.isAnalysisSupported, isTrue);
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
          bicepsDefinition.analysisCameraViewContract.supportFor(
            CameraView.front,
          ),
          CameraViewSupport.preferred,
        );
        expect(
          bicepsDefinition.analysisCameraViewContract.supportFor(
            CameraView.side,
          ),
          CameraViewSupport.unsupported,
        );
        expect(
          bicepsContent.setupSteps.join(' '),
          contains('kamerayı doğrudan karşıdan'),
        );
        expect(
          bicepsContent.tips.join(' '),
          contains('Dirseklerini gövdeye yakın ve sabit tut.'),
        );
      },
    );

    test(
      'lateral raise guide stays aligned with the bilateral front-view contract',
      () {
        final lateralDefinition = analysisCatalog.definitionFor(
          ExerciseType.lateralRaise,
        );
        final lateralContent = guideCatalog.contentFor(
          ExerciseType.lateralRaise,
        );

        expect(lateralDefinition.isAnalysisSupported, isTrue);
        expect(lateralDefinition.analysisEngineKind.name, 'rangeRep');
        expect(lateralContent.type, ExerciseType.lateralRaise);
        expect(
          lateralDefinition.analysisCameraViewContract.supportFor(
            CameraView.front,
          ),
          CameraViewSupport.preferred,
        );
        expect(
          lateralDefinition.analysisCameraViewContract.supportFor(
            CameraView.side,
          ),
          CameraViewSupport.unsupported,
        );
        expect(
          lateralContent.setupSteps.join(' '),
          contains('Kameraya önden bak'),
        );
        expect(
          lateralContent.setupSteps.join(' '),
          contains('iki omuz-dirsek-bilek hattını kadraja al'),
        );
        expect(
          lateralContent.tips.join(' '),
          contains('Omuz hizası civarında'),
        );
      },
    );

    test(
      'front raise guide stays aligned with the selected-side side-view contract',
      () {
        final frontRaiseDefinition = analysisCatalog.definitionFor(
          ExerciseType.frontRaise,
        );
        final frontRaiseContent = guideCatalog.contentFor(
          ExerciseType.frontRaise,
        );

        expect(frontRaiseDefinition.isAnalysisSupported, isTrue);
        expect(frontRaiseDefinition.analysisEngineKind.name, 'rangeRep');
        expect(frontRaiseContent.type, ExerciseType.frontRaise);
        expect(
          frontRaiseDefinition.analysisCameraViewContract.supportFor(
            CameraView.side,
          ),
          CameraViewSupport.preferred,
        );
        expect(
          frontRaiseDefinition.analysisCameraViewContract.supportFor(
            CameraView.front,
          ),
          CameraViewSupport.unsupported,
        );
        expect(
          frontRaiseContent.setupSteps.join(' '),
          contains('Kamerayı yandan'),
        );
        expect(
          frontRaiseContent.setupSteps.join(' '),
          contains('omuz-dirsek-bilek ve kalça hattını'),
        );
        expect(
          frontRaiseContent.tips.join(' '),
          contains('Omuz hizası civarında'),
        );
      },
    );

    test('bench dip guide freezes the canonical bench-supported scope', () {
      final definition = analysisCatalog.definitionFor(ExerciseType.tricepsDip);
      final content = guideCatalog.contentFor(ExerciseType.tricepsDip);

      expect(ExerciseType.tricepsDip.id, 'triceps_dip');
      expect(ExerciseType.tricepsDip.title, 'Bench Dip');
      expect(definition.isAnalysisSupported, isTrue);
      expect(
        definition.analysisCameraViewContract.supportFor(CameraView.side),
        CameraViewSupport.preferred,
      );
      expect(
        definition.analysisCameraViewContract.supportFor(CameraView.front),
        CameraViewSupport.unsupported,
      );
      expect(content.difficulty.name, 'intermediate');
      expect(content.setupSteps.join(' '), contains('bench veya yükseltinin'));
      expect(content.setupSteps.join(' '), isNot(contains('Paralel bar')));
      expect(content.tips.join(' '), contains('yaklaşık 90 derece'));
      expect(content.youtubeSourceLabel, 'Bench dip technique reference');
    });

    test(
      'romanian deadlift guide stays aligned with the selected-side side-view contract',
      () {
        final rdlDefinition = analysisCatalog.definitionFor(
          ExerciseType.romanianDeadlift,
        );
        final rdlContent = guideCatalog.contentFor(
          ExerciseType.romanianDeadlift,
        );

        expect(rdlDefinition.isAnalysisSupported, isTrue);
        expect(rdlDefinition.analysisEngineKind.name, 'rangeRep');
        expect(rdlContent.type, ExerciseType.romanianDeadlift);
        expect(
          rdlDefinition.analysisCameraViewContract.supportFor(CameraView.side),
          CameraViewSupport.preferred,
        );
        expect(
          rdlDefinition.analysisCameraViewContract.supportFor(CameraView.front),
          CameraViewSupport.unsupported,
        );
        expect(
          rdlContent.setupSteps.join(' '),
          contains('kamerayı tam yandan'),
        );
        expect(
          rdlContent.setupSteps.join(' '),
          contains('Dizlerini hafif bük'),
        );
        expect(
          rdlContent.tips.join(' '),
          contains('Hareketi dizlerden çok kalçadan başlat'),
        );
      },
    );

    test('wall sit guide stays aligned with the side-view hold contract', () {
      final wallSitDefinition = analysisCatalog.definitionFor(
        ExerciseType.wallSit,
      );
      final wallSitContent = guideCatalog.contentFor(ExerciseType.wallSit);

      expect(wallSitDefinition.isAnalysisSupported, isTrue);
      expect(wallSitDefinition.analysisEngineKind.name, 'hold');
      expect(wallSitContent.type, ExerciseType.wallSit);
      expect(
        wallSitDefinition.analysisCameraViewContract.supportFor(
          CameraView.side,
        ),
        CameraViewSupport.preferred,
      );
      expect(
        wallSitDefinition.analysisCameraViewContract.supportFor(
          CameraView.front,
        ),
        CameraViewSupport.unsupported,
      );
      expect(wallSitContent.setupSteps.join(' '), contains('kamerayı yandan'));
      expect(
        wallSitContent.setupSteps.join(' '),
        contains('Baş, omuz, kalça, diz ve ayak bileğinin'),
      );
    });

    test('hollow hold guide stays available on the canonical hold owner', () {
      final hollowDefinition = analysisCatalog.definitionFor(
        ExerciseType.hollowHold,
      );
      final hollowContent = guideCatalog.contentFor(ExerciseType.hollowHold);

      expect(hollowDefinition.isAnalysisSupported, isTrue);
      expect(hollowDefinition.analysisEngineKind.name, 'hold');
      expect(hollowContent.type, ExerciseType.hollowHold);
      expect(hollowContent.setupSteps.join(' '), contains('Sırt üstü uzan'));
      expect(
        hollowContent.tips.join(' '),
        contains('Kolları kulaklara yakın uzat'),
      );
    });
  });
}
