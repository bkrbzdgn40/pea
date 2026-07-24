import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/analysis_engine_factory.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_catalog.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_type.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/range_rep_analysis_engine.dart';

import '../../../support/workout_analysis_test_support.dart';

void main() {
  const catalog = ExerciseCatalog();
  const factory = AnalysisEngineFactory();
  final definition = catalog.definitionFor(ExerciseType.tricepsDip);

  group('Bench Dip production contract', () {
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

    test('counts a controlled near-90-degree bottom lifecycle', () {
      _confirm(engine, clock, 165);
      _confirm(engine, clock, 126);
      _confirm(engine, clock, 96);
      _confirm(engine, clock, 126);
      _confirm(engine, clock, 160);

      expect(engine.repCount, 1);
    });

    test(
      'recovers a valid bottom sampled during active-entry confirmation',
      () {
        _confirm(engine, clock, 165);

        engine.updateDetectionFrame(primaryMetric: 96);
        clock.advance(const Duration(milliseconds: 120));
        final started = engine.updateDetectionFrame(primaryMetric: 126);

        expect(started.repStarted, isTrue);
        expect(engine.phaseLabel, 'DESCENDING');

        clock.advance(const Duration(milliseconds: 20));
        final recoveredPeak = engine.updateDetectionFrame(primaryMetric: 126);

        expect(recoveredPeak.confirmedTransition?.type.name, 'reachPeak');
        expect(engine.phaseLabel, 'PEAK');

        _confirm(engine, clock, 126);
        _confirm(engine, clock, 165);

        expect(engine.repCount, 1);
      },
    );

    test('recovers a strict bottom followed directly by neutral', () {
      _confirm(engine, clock, 165);
      clock.advance(const Duration(milliseconds: 100));

      final peak = engine.updateDetectionFrame(primaryMetric: 93);

      expect(
        peak.confirmedTransitions.map((transition) => transition.type.name),
        <String>['startDescending', 'reachPeak'],
      );
      expect(engine.phaseLabel, 'PEAK');

      clock.advance(const Duration(milliseconds: 250));
      final completed = engine.updateDetectionFrame(primaryMetric: 165);

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

    test('keeps a shallow 103-degree excursion below completed-rep scope', () {
      _confirm(engine, clock, 165);
      _confirm(engine, clock, 126);
      _confirm(engine, clock, 103);
      _confirm(engine, clock, 160);

      expect(engine.repCount, 0);
      expect(engine.phaseLabel, 'NEUTRAL');
      expect(engine.detectionDiagnosticsSnapshot.hasActiveRepPhase, isFalse);
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
