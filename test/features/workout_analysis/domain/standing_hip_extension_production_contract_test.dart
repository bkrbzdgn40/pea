import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/analysis_engine_factory.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_catalog.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/analysis_frame.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_config.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_type.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/range_rep_engine_frame_result.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/range_rep_feedback_code.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/range_rep_analysis_engine.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/range_rep_engine.dart';

import '../../../support/workout_analysis_test_support.dart';

void main() {
  const catalog = ExerciseCatalog();
  const factory = AnalysisEngineFactory();
  final definition = catalog.definitionFor(ExerciseType.standingHipExtension);

  group('Standing Hip Extension production contract', () {
    late TestFakeClock clock;
    late ExerciseConfig config;
    late RangeRepAnalysisEngine engine;

    setUp(() {
      clock = TestFakeClock();
      config = loadExerciseConfig(definition.analysisConfigAssetPath);
      engine = factory.createRangeRep(
        config: config,
        rangeRepContract: definition.analysisRangeRepContract,
        now: clock.now,
      );
    });

    test('uses the device-calibrated 160-degree peak window', () {
      expect(config.thresholdNeutral, 172.0);
      expect(config.thresholdActive, 170.0);
      expect(config.thresholdPeak, 163.0);
      expect(config.targetMinAngle, 160.0);
      expect(definition.analysisRangeRepContract.peakEntryMargin, 0.0);
      expect(
        definition
            .analysisRangeRepContract
            .retainPeakEvidenceAcrossActiveTransition,
        isTrue,
      );
      expect(
        definition.analysisRangeRepValidationConfig.minAcceptableRomDelta,
        10.0,
      );
    });

    test('counts a controlled rep reaching 160 degrees', () {
      _confirm(engine, clock, 176);
      _confirm(engine, clock, 166);
      _confirm(engine, clock, 160);
      _confirm(engine, clock, 172);
      final completed = _confirm(engine, clock, 176);

      expect(engine.repCount, 1);
      expect(engine.phaseLabel, 'NEUTRAL');
      expect(completed.didCompleteRep, isTrue);
      expect(
        completed.completedRepDetectionData?.primaryRom,
        closeTo(16.0, 0.001),
      );
    });

    test('maps the 160-degree peak to return guidance and success', () {
      final compatibilityEngine = engine as RangeRepEngine;

      _confirmCompatibility(compatibilityEngine, clock, 176);
      _confirmCompatibility(compatibilityEngine, clock, 166);
      _confirmCompatibility(compatibilityEngine, clock, 160);

      expect(compatibilityEngine.feedbackCode, RangeRepFeedbackCode.ascend);

      _confirmCompatibility(compatibilityEngine, clock, 172);
      _confirmCompatibility(compatibilityEngine, clock, 176);

      expect(compatibilityEngine.repCount, 1);
      expect(
        compatibilityEngine.feedbackCode,
        RangeRepFeedbackCode.repCompleted,
      );
    });

    test('does not count a 166-degree shallow excursion', () {
      _confirm(engine, clock, 176);
      _confirm(engine, clock, 166);
      _confirm(engine, clock, 165);
      _confirm(engine, clock, 176);

      expect(engine.repCount, 0);
      expect(engine.phaseLabel, 'NEUTRAL');
    });
  });
}

RangeRepEngineFrameResult _confirm(
  RangeRepAnalysisEngine engine,
  TestFakeClock clock,
  double primaryMetric,
) {
  engine.updateDetectionFrame(primaryMetric: primaryMetric);
  clock.advance(const Duration(milliseconds: 320));
  final result = engine.updateDetectionFrame(primaryMetric: primaryMetric);
  clock.advance(const Duration(milliseconds: 20));
  return result;
}

void _confirmCompatibility(
  RangeRepEngine engine,
  TestFakeClock clock,
  double primaryMetric,
) {
  engine.update(AnalysisFrame(primaryMetric: primaryMetric, formMetric: 180));
  clock.advance(const Duration(milliseconds: 320));
  engine.update(AnalysisFrame(primaryMetric: primaryMetric, formMetric: 180));
  clock.advance(const Duration(milliseconds: 20));
}
