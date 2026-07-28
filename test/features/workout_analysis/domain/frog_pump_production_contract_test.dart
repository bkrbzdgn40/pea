import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/analysis_engine_factory.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_catalog.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_config.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_type.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/range_rep_engine_frame_result.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/range_rep_analysis_engine.dart';

import '../../../support/workout_analysis_test_support.dart';

void main() {
  const catalog = ExerciseCatalog();
  const factory = AnalysisEngineFactory();
  final definition = catalog.definitionFor(ExerciseType.frogPump);

  group('Frog Pump production contract', () {
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

    test('accepts the observed 150-degree floor setup as neutral', () {
      expect(config.thresholdNeutral, 152.0);
      expect(config.thresholdActive, 158.0);
      expect(config.thresholdPeak, 165.0);
      expect(definition.analysisRangeRepContract.peakEntryMargin, 0.0);
      expect(
        definition
            .analysisRangeRepContract
            .retainPeakEvidenceAcrossActiveTransition,
        isTrue,
      );
      expect(
        definition.analysisRangeRepContract.initialNeutralConfirmationDuration,
        const Duration(milliseconds: 600),
      );

      _confirmInitialNeutral(engine, clock, 150);

      expect(engine.phaseLabel, 'NEUTRAL');
      expect(engine.repCount, 0);
    });

    test('counts a controlled floor-neutral to hip-extension lifecycle', () {
      _confirmInitialNeutral(engine, clock, 150);
      _confirm(engine, clock, 162);
      _confirm(engine, clock, 168);
      _confirm(engine, clock, 156);
      final completed = _confirm(engine, clock, 150);

      expect(engine.repCount, 1);
      expect(engine.phaseLabel, 'NEUTRAL');
      expect(completed.didCompleteRep, isTrue);
      expect(
        completed.completedRepDetectionData?.primaryRom,
        closeTo(18.0, 0.001),
      );
    });

    test('does not arm from a 156-degree raised-hip pose', () {
      _confirmInitialNeutral(engine, clock, 156);

      expect(engine.phaseLabel, 'AWAITING_NEUTRAL');
      expect(engine.repCount, 0);
    });
  });
}

void _confirmInitialNeutral(
  RangeRepAnalysisEngine engine,
  TestFakeClock clock,
  double primaryMetric,
) {
  engine.updateDetectionFrame(primaryMetric: primaryMetric);
  clock.advance(const Duration(milliseconds: 600));
  engine.updateDetectionFrame(primaryMetric: primaryMetric);
  clock.advance(const Duration(milliseconds: 20));
}

RangeRepEngineFrameResult _confirm(
  RangeRepAnalysisEngine engine,
  TestFakeClock clock,
  double primaryMetric,
) {
  engine.updateDetectionFrame(primaryMetric: primaryMetric);
  clock.advance(const Duration(milliseconds: 120));
  final result = engine.updateDetectionFrame(primaryMetric: primaryMetric);
  clock.advance(const Duration(milliseconds: 20));
  return result;
}
