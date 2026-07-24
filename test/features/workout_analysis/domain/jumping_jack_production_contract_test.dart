import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/analysis_engine_factory.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_catalog.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_type.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/range_rep_analysis_engine.dart';

import '../../../support/workout_analysis_test_support.dart';

void main() {
  const catalog = ExerciseCatalog();
  const factory = AnalysisEngineFactory();
  final definition = catalog.definitionFor(ExerciseType.jumpingJack);

  group('Jumping Jack production contract', () {
    late TestFakeClock clock;
    late RangeRepAnalysisEngine engine;

    setUp(() {
      clock = TestFakeClock();
      engine = factory.createRangeRep(
        config: loadExerciseConfig(definition.analysisConfigAssetPath),
        rangeRepContract: definition.analysisRangeRepContract,
        now: clock.now,
      );
    });

    test('recovers a device-observed peak during active confirmation', () {
      _confirm(engine, clock, 10);

      engine.updateDetectionFrame(primaryMetric: 125);
      clock.advance(const Duration(milliseconds: 120));
      final started = engine.updateDetectionFrame(primaryMetric: 100);

      expect(started.repStarted, isTrue);
      expect(engine.phaseLabel, 'DESCENDING');

      clock.advance(const Duration(milliseconds: 20));
      final recoveredPeak = engine.updateDetectionFrame(primaryMetric: 100);

      expect(recoveredPeak.confirmedTransition?.type.name, 'reachPeak');
      expect(engine.phaseLabel, 'PEAK');

      _confirm(engine, clock, 100);
      _confirm(engine, clock, 10);

      expect(engine.repCount, 1);
    });

    test('recovers a device-observed peak followed by closed neutral', () {
      _confirm(engine, clock, 10);
      clock.advance(const Duration(milliseconds: 100));

      final peak = engine.updateDetectionFrame(primaryMetric: 125);

      expect(
        peak.confirmedTransitions.map((transition) => transition.type.name),
        <String>['startDescending', 'reachPeak'],
      );
      expect(engine.phaseLabel, 'PEAK');

      clock.advance(const Duration(milliseconds: 250));
      final completed = engine.updateDetectionFrame(primaryMetric: 10);

      expect(
        completed.confirmedTransitions.map(
          (transition) => transition.type.name,
        ),
        <String>['startAscending', 'completeRep'],
      );
      expect(completed.didCompleteRep, isTrue);
      expect(engine.repCount, 1);
      expect(engine.phaseLabel, 'NEUTRAL');
    });

    test('rejects a partial opening below the calibrated peak band', () {
      _confirm(engine, clock, 10);

      engine.updateDetectionFrame(primaryMetric: 112);
      clock.advance(const Duration(milliseconds: 120));
      engine.updateDetectionFrame(primaryMetric: 100);
      clock.advance(const Duration(milliseconds: 20));
      _confirm(engine, clock, 10);

      expect(engine.repCount, 0);
      expect(engine.phaseLabel, 'NEUTRAL');
    });
  });
}

void _confirm(
  RangeRepAnalysisEngine engine,
  TestFakeClock clock,
  double metric,
) {
  engine.updateDetectionFrame(primaryMetric: metric);
  clock.advance(const Duration(milliseconds: 120));
  engine.updateDetectionFrame(primaryMetric: metric);
  clock.advance(const Duration(milliseconds: 20));
}
