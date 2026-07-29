import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_catalog.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/legacy_range_rep_technique_evaluator.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_config.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_type.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/range_rep_contract.dart';

void main() {
  const catalog = ExerciseCatalog();
  const packageTypes = <ExerciseType>{
    ExerciseType.standingHipExtension,
    ExerciseType.standingKneeRaise,
    ExerciseType.standingStraightLegRaise,
    ExerciseType.vUp,
    ExerciseType.frogPump,
    ExerciseType.lyingTricepsExtension,
    ExerciseType.floorChestPress,
    ExerciseType.yRaise,
  };

  test('package two assets parse with explicit RangeRep signals', () {
    for (final type in packageTypes) {
      final definition = catalog.definitionFor(type);
      final file = File(definition.analysisConfigAssetPath);
      expect(file.existsSync(), isTrue, reason: type.id);

      final config = ExerciseConfig.fromMap(
        jsonDecode(file.readAsStringSync()) as Map<String, dynamic>,
      );
      final contract = definition.analysisRangeRepContract;

      expect(config.name.trim(), isNotEmpty, reason: type.id);
      expect(config.rangeRepSignals, isNotNull, reason: type.id);
      expect(config.usesLegacyRangeRepSignalFallback, isFalse, reason: type.id);

      switch (contract.primaryMetricDirection) {
        case RangeRepPrimaryMetricDirection.decreasingToPeak:
          expect(
            config.thresholdNeutral,
            greaterThan(config.thresholdActive),
            reason: type.id,
          );
          expect(
            config.thresholdActive,
            greaterThan(config.thresholdPeak),
            reason: type.id,
          );
        case RangeRepPrimaryMetricDirection.increasingToPeak:
          expect(
            config.thresholdNeutral,
            lessThan(config.thresholdActive),
            reason: type.id,
          );
          expect(
            config.thresholdActive,
            lessThan(config.thresholdPeak),
            reason: type.id,
          );
          expect(config.targetMaxAngle, isNotNull, reason: type.id);
      }
    }
  });

  test('Y raise allows a soft elbow bend before form feedback', () {
    final definition = catalog.definitionFor(ExerciseType.yRaise);
    final config = ExerciseConfig.fromMap(
      jsonDecode(File(definition.analysisConfigAssetPath).readAsStringSync())
          as Map<String, dynamic>,
    );
    const evaluator = LegacyRangeRepTechniqueEvaluator();

    expect(config.formThreshold, 145.0);
    expect(
      evaluator
          .evaluate(formMetric: 145.0, formThreshold: config.formThreshold)
          .hasObservations,
      isFalse,
    );
    expect(
      evaluator
          .evaluate(formMetric: 144.0, formThreshold: config.formThreshold)
          .hasObservations,
      isTrue,
    );
  });

  test('knee raise uses knee-flexion form and Y raise is bilateral', () {
    final kneeRaise = ExerciseConfig.fromMap(
      jsonDecode(
            File(
              catalog
                  .definitionFor(ExerciseType.standingKneeRaise)
                  .analysisConfigAssetPath,
            ).readAsStringSync(),
          )
          as Map<String, dynamic>,
    );

    expect(
      kneeRaise.rangeRepSignals?.postureAngle?.transform,
      RangeRepSignalTransform.complement180,
    );
    expect(
      catalog
          .definitionFor(ExerciseType.yRaise)
          .analysisRangeRepContract
          .sideMode,
      RangeRepSideMode.bilateral,
    );
  });
}
