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
  final definition = catalog.definitionFor(ExerciseType.standingHipAbduction);

  group('Standing Hip Abduction production contract', () {
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

    test(
      'uses the 140-degree peak, 173-degree start, and 168-degree finish',
      () {
        expect(config.thresholdNeutral, 173.0);
        expect(config.thresholdActive, 155.0);
        expect(config.thresholdPeak, 140.0);
        expect(definition.analysisRangeRepContract.peakEntryMargin, 0.0);
        expect(definition.analysisRangeRepContract.completionThreshold, 168.0);
        expect(
          definition.analysisRangeRepContract.neutralBaselineWindow,
          const Duration(milliseconds: 1500),
        );
        expect(
          definition.analysisRangeRepContract.neutralBaselineThresholdMargin,
          0.0,
        );
        expect(
          definition.analysisRangeRepValidationConfig.minAcceptableRomDelta,
          25.0,
        );
      },
    );

    test('counts a controlled rep that reaches the calibrated peak window', () {
      _confirm(engine, clock, 176);
      _confirm(engine, clock, 150);
      _confirm(engine, clock, 139);
      _confirm(engine, clock, 150);

      final belowFinish = _confirm(engine, clock, 167);
      expect(engine.repCount, 0);
      expect(engine.phaseLabel, 'ASCENDING');
      expect(belowFinish.didCompleteRep, isFalse);

      final completed = _confirm(engine, clock, 168);

      expect(engine.repCount, 1);
      expect(engine.phaseLabel, 'NEUTRAL');
      expect(completed.didCompleteRep, isTrue);
      expect(
        completed.completedRepDetectionData?.primaryRom,
        closeTo(37.0, 0.001),
      );
    });

    test(
      'keeps repeated device-calibrated reps anchored to the 173-degree neutral',
      () {
        const deviceObservedPeaks = <double>[127.0, 130.0, 132.0, 135.0];

        for (final peak in deviceObservedPeaks) {
          _confirm(engine, clock, 174.0);
          _confirm(engine, clock, 150.0);
          _confirm(engine, clock, peak);
          _confirm(engine, clock, 150.0);
          final completed = _confirm(engine, clock, 168.0);
          final detectionData = completed.completedRepDetectionData;

          expect(detectionData, isNotNull);
          expect(detectionData!.startAngle, closeTo(174.0, 0.001));
          expect(
            detectionData.primaryRom,
            greaterThanOrEqualTo(25.0),
            reason: 'peak=$peak',
          );
        }

        expect(engine.repCount, deviceObservedPeaks.length);
      },
    );

    test('does not count a shallow excursion that stays above 140 degrees', () {
      _confirm(engine, clock, 176);
      _confirm(engine, clock, 150);
      _confirm(engine, clock, 141);
      _confirm(engine, clock, 150);
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
