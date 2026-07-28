import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/app/localization/app_localizations.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_catalog.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_definition.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_definition_metadata.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_type.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/mappers/exercise_setup_ui_mapper.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/models/preparation_pose_guide.dart';

void main() {
  const catalog = ExerciseCatalog();
  const turkish = AppLocalizations(Locale('tr'));
  const english = AppLocalizations(Locale('en'));

  test('projects localized setup copy for every canonical exercise', () {
    expect(catalog.definitions, hasLength(ExerciseType.values.length));

    for (final definition in catalog.definitions) {
      final trViewData = mapExerciseSetupToViewData(
        definition: definition,
        localizations: turkish,
      );
      final enViewData = mapExerciseSetupToViewData(
        definition: definition,
        localizations: english,
      );

      expect(trViewData.exerciseId, definition.id);
      expect(trViewData.exerciseName, turkish.exerciseTitle(definition.id));
      expect(enViewData.exerciseName, english.exerciseTitle(definition.id));
      expect(trViewData.cameraViewLabel, isNotEmpty);
      expect(trViewData.cameraViewInstruction, isNotEmpty);
      expect(trViewData.bodyCoverageInstruction, isNotEmpty);
      expect(trViewData.startPoseInstruction, isNotEmpty);
      expect(trViewData.startPoseGuideTitle, isNotEmpty);
      expect(trViewData.startPoseGuideHint, isNotEmpty);
      expect(trViewData.setupPositionLabel, isNotEmpty);
      expect(trViewData.cameraPlacementInstruction, isNotEmpty);
      expect(trViewData.environmentInstructions, isNotEmpty);
      expect(enViewData.orderedInstructions, isNotEmpty);
      expect(
        trViewData.orderedInstructions.any((copy) => copy.contains('Family')),
        isFalse,
      );
      expect(
        enViewData.orderedInstructions.any(
          (copy) => copy.contains('SetupBodyRegion'),
        ),
        isFalse,
      );
    }
  });

  test('reads preferred view from the existing camera contract', () {
    final squat = mapExerciseSetupToViewData(
      definition: catalog.definitionFor(ExerciseType.squat),
      localizations: turkish,
    );
    final bicepsCurl = mapExerciseSetupToViewData(
      definition: catalog.definitionFor(ExerciseType.bicepsCurl),
      localizations: turkish,
    );

    expect(squat.cameraViewLabel, 'Yandan görünüm');
    expect(squat.cameraViewInstruction, contains('yanını kameraya dön'));
    expect(bicepsCurl.cameraViewLabel, 'Önden görünüm');
    expect(bicepsCurl.cameraViewInstruction, 'Doğrudan kameraya dön.');
  });

  test('projects exercise-aware start pose copy aligned with guide scope', () {
    final squat = mapExerciseSetupToViewData(
      definition: catalog.definitionFor(ExerciseType.squat),
      localizations: turkish,
    );
    final plank = mapExerciseSetupToViewData(
      definition: catalog.definitionFor(ExerciseType.plank),
      localizations: english,
    );
    final bicepsCurl = mapExerciseSetupToViewData(
      definition: catalog.definitionFor(ExerciseType.bicepsCurl),
      localizations: english,
    );
    final benchDip = mapExerciseSetupToViewData(
      definition: catalog.definitionFor(ExerciseType.tricepsDip),
      localizations: english,
    );
    final sidePlank = mapExerciseSetupToViewData(
      definition: catalog.definitionFor(ExerciseType.sidePlank),
      localizations: turkish,
    );
    final sitUp = mapExerciseSetupToViewData(
      definition: catalog.definitionFor(ExerciseType.sitUp),
      localizations: turkish,
    );
    final reverseCrunch = mapExerciseSetupToViewData(
      definition: catalog.definitionFor(ExerciseType.reverseCrunch),
      localizations: turkish,
    );
    final lyingLegRaise = mapExerciseSetupToViewData(
      definition: catalog.definitionFor(ExerciseType.lyingLegRaise),
      localizations: turkish,
    );
    final bentKneeLegRaise = mapExerciseSetupToViewData(
      definition: catalog.definitionFor(ExerciseType.bentKneeLegRaise),
      localizations: turkish,
    );
    final gluteBridge = mapExerciseSetupToViewData(
      definition: catalog.definitionFor(ExerciseType.gluteBridge),
      localizations: turkish,
    );
    final shoulderPress = mapExerciseSetupToViewData(
      definition: catalog.definitionFor(ExerciseType.shoulderPress),
      localizations: turkish,
    );
    final hollowHold = mapExerciseSetupToViewData(
      definition: catalog.definitionFor(ExerciseType.hollowHold),
      localizations: turkish,
    );
    final vUp = mapExerciseSetupToViewData(
      definition: catalog.definitionFor(ExerciseType.vUp),
      localizations: turkish,
    );
    final frogPump = mapExerciseSetupToViewData(
      definition: catalog.definitionFor(ExerciseType.frogPump),
      localizations: turkish,
    );
    final lyingTricepsExtension = mapExerciseSetupToViewData(
      definition: catalog.definitionFor(ExerciseType.lyingTricepsExtension),
      localizations: turkish,
    );
    final floorChestPress = mapExerciseSetupToViewData(
      definition: catalog.definitionFor(ExerciseType.floorChestPress),
      localizations: turkish,
    );

    expect(squat.startPoseInstruction, contains('omuz genişliğinde'));
    expect(plank.startPoseInstruction, contains('elbows under your shoulders'));
    expect(bicepsCurl.startPoseInstruction, contains('both arms down'));
    expect(benchDip.startPoseInstruction, contains('stable raised surface'));
    expect(benchDip.startPoseInstruction, isNot(contains('parallel bar')));
    expect(sidePlank.startPoseInstruction, contains('dirseğini veya elini'));
    expect(
      squat.startPoseTemplate,
      PreparationPoseTemplate.standingNeutralSide,
    );
    expect(plank.startPoseTemplate, PreparationPoseTemplate.floorProneSupport);
    expect(
      bicepsCurl.startPoseTemplate,
      PreparationPoseTemplate.standingArmsDownFront,
    );
    expect(benchDip.startPoseTemplate, PreparationPoseTemplate.benchDipSetup);
    expect(benchDip.startPoseGuideHint, contains('front edge'));
    expect(
      sitUp.startPoseTemplate,
      PreparationPoseTemplate.floorSupineBentKnees,
    );
    expect(
      reverseCrunch.startPoseTemplate,
      PreparationPoseTemplate.floorSupineBentKnees,
    );
    expect(
      lyingLegRaise.startPoseTemplate,
      PreparationPoseTemplate.floorSupineBentKnees,
    );
    expect(
      bentKneeLegRaise.startPoseTemplate,
      PreparationPoseTemplate.floorSupineBentKnees,
    );
    expect(
      gluteBridge.startPoseTemplate,
      PreparationPoseTemplate.floorSupineBentKnees,
    );
    expect(
      shoulderPress.startPoseTemplate,
      PreparationPoseTemplate.shoulderPressRack,
    );
    expect(
      hollowHold.startPoseTemplate,
      PreparationPoseTemplate.floorSupineStraight,
    );
    expect(vUp.startPoseTemplate, PreparationPoseTemplate.floorSupineStraight);
    expect(
      frogPump.startPoseTemplate,
      PreparationPoseTemplate.floorSupineBentKnees,
    );
    expect(
      lyingTricepsExtension.startPoseTemplate,
      PreparationPoseTemplate.floorSupineElbowsBentOverhead,
    );
    expect(
      floorChestPress.startPoseTemplate,
      PreparationPoseTemplate.floorSupineChestPress,
    );
    expect(sidePlank.startPoseGuideTitle, isNotEmpty);
    expect(sidePlank.startPoseGuideHint, contains('iskelete'));
  });

  test('derives body coverage from the setup contract', () {
    final calfRaise = mapExerciseSetupToViewData(
      definition: catalog.definitionFor(ExerciseType.calfRaise),
      localizations: turkish,
    );
    final shoulderPress = mapExerciseSetupToViewData(
      definition: catalog.definitionFor(ExerciseType.shoulderPress),
      localizations: english,
    );

    expect(calfRaise.bodyCoverageInstruction, contains('Kalçan'));
    expect(calfRaise.bodyCoverageInstruction, contains('ayakların'));
    expect(calfRaise.bodyCoverageInstruction, isNot(contains('omuzların')));
    expect(shoulderPress.bodyCoverageInstruction, contains('head'));
    expect(shoulderPress.bodyCoverageInstruction, contains('wrists'));
  });

  test('projects support, camera height, and environment requirements', () {
    final plank = mapExerciseSetupToViewData(
      definition: catalog.definitionFor(ExerciseType.plank),
      localizations: turkish,
    );
    final wallSit = mapExerciseSetupToViewData(
      definition: catalog.definitionFor(ExerciseType.wallSit),
      localizations: english,
    );
    final benchDip = mapExerciseSetupToViewData(
      definition: catalog.definitionFor(ExerciseType.tricepsDip),
      localizations: turkish,
    );
    final jumpingJack = mapExerciseSetupToViewData(
      definition: catalog.definitionFor(ExerciseType.jumpingJack),
      localizations: english,
    );

    expect(plank.setupPositionLabel, 'Yerde');
    expect(plank.cameraPlacementInstruction, contains('yere yakın'));
    expect(plank.environmentInstructions.join(' '), contains('Yerde uzan'));
    expect(wallSit.setupPositionLabel, 'Wall-supported');
    expect(wallSit.environmentInstructions.join(' '), contains('stable wall'));
    expect(benchDip.setupPositionLabel, 'Yükselti destekli');
    expect(benchDip.environmentInstructions.join(' '), contains('Yükseltinin'));
    expect(benchDip.environmentInstructions.join(' '), contains('bench'));
    expect(
      jumpingJack.environmentInstructions.join(' '),
      contains('overhead space'),
    );
  });

  test('keeps presentation collections immutable and stably ordered', () {
    final viewData = mapExerciseSetupToViewData(
      definition: catalog.definitionFor(ExerciseType.squat),
      localizations: english,
    );

    expect(
      () => viewData.environmentInstructions.add('extra'),
      throwsUnsupportedError,
    );
    expect(
      () => viewData.orderedInstructions.add('extra'),
      throwsUnsupportedError,
    );
    expect(viewData.orderedInstructions.first, viewData.cameraViewInstruction);
    expect(viewData.orderedInstructions[1], viewData.bodyCoverageInstruction);
    expect(viewData.orderedInstructions[2], viewData.startPoseInstruction);
    expect(
      viewData.orderedInstructions[3],
      viewData.cameraPlacementInstruction,
    );
  });

  test('rejects unsupported definitions instead of inventing setup copy', () {
    const unsupported = ExerciseDefinition.unsupported(
      type: ExerciseType.squat,
      movementPattern: ExerciseMovementPattern.squat,
      trackingType: ExerciseTrackingType.repetitions,
    );

    expect(
      () => mapExerciseSetupToViewData(
        definition: unsupported,
        localizations: turkish,
      ),
      throwsStateError,
    );
  });
}
