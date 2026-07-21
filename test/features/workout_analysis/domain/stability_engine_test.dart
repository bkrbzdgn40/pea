import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/stability_engine.dart';

void main() {
  group('StabilityEngine', () {
    test('keeps stability unmeasured until enough samples exist', () {
      final engine = StabilityEngine<String>();

      engine.beginWindow();
      engine.recordSample(<String, double>{'alignment': 170.0});

      expect(engine.currentWindowSummary, isNotNull);
      expect(engine.currentWindowSummary!.sampleCount, 1);
      expect(engine.currentWindowSummary!.averageStandardDeviation, isNull);
      expect(engine.currentWindowSummary!.stabilityScore, isNull);
      expect(engine.sessionSummary.stabilityScore, isNull);
    });

    test('scores a perfectly constant signal at 100', () {
      final engine = StabilityEngine<String>();

      engine.beginWindow();
      engine.recordSample(<String, double>{'alignment': 170.0});
      engine.recordSample(<String, double>{'alignment': 170.0});

      final summary = engine.currentWindowSummary!;
      expect(summary.averageStandardDeviation, 0.0);
      expect(summary.stabilityScore, 100.0);
    });

    test('normalizes observed signal deviation into a stability score', () {
      final engine = StabilityEngine<String>(
        config: const StabilityEngineConfig(standardDeviationAtZeroScore: 10.0),
      );

      engine.beginWindow();
      engine.recordSample(<String, double>{'alignment': 0.0});
      engine.recordSample(<String, double>{'alignment': 10.0});

      final summary = engine.currentWindowSummary!;
      expect(summary.averageStandardDeviation, closeTo(5.0, 0.001));
      expect(summary.stabilityScore, closeTo(50.0, 0.001));
    });

    test('averages measured deviation across independent signals', () {
      final engine = StabilityEngine<String>(
        config: const StabilityEngineConfig(standardDeviationAtZeroScore: 10.0),
      );

      engine.beginWindow();
      engine.recordSample(<String, double>{'a': 0.0, 'b': 10.0});
      engine.recordSample(<String, double>{'a': 10.0, 'b': 10.0});

      final summary = engine.currentWindowSummary!;
      expect(summary.signalSummaries['a']!.standardDeviation, 5.0);
      expect(summary.signalSummaries['b']!.standardDeviation, 0.0);
      expect(summary.averageStandardDeviation, closeTo(2.5, 0.001));
      expect(summary.stabilityScore, closeTo(75.0, 0.001));
    });

    test('finalizes window results while preserving session aggregation', () {
      final engine = StabilityEngine<String>();

      engine.beginWindow();
      engine.recordSample(<String, double>{'alignment': 170.0});
      engine.recordSample(<String, double>{'alignment': 170.0});
      final completed = engine.endWindow();

      expect(completed, isNotNull);
      expect(completed!.sampleCount, 2);
      expect(completed.stabilityScore, 100.0);
      expect(engine.currentWindowSummary, isNull);
      expect(engine.lastCompletedWindow, same(completed));
      expect(engine.sessionSummary.sampleCount, 2);
      expect(engine.sessionSummary.stabilityScore, 100.0);
    });

    test('ignores non-finite samples and reset clears all history', () {
      final engine = StabilityEngine<String>();

      engine.beginWindow();
      engine.recordSample(<String, double>{'alignment': double.nan});
      engine.recordSample(<String, double>{'alignment': double.infinity});

      expect(engine.currentWindowSummary!.sampleCount, 0);
      expect(engine.sessionSummary.sampleCount, 0);

      engine.recordSample(<String, double>{'alignment': 170.0});
      engine.recordSample(<String, double>{'alignment': 170.0});
      engine.endWindow();
      engine.reset();

      expect(engine.currentWindowSummary, isNull);
      expect(engine.lastCompletedWindow, isNull);
      expect(engine.sessionSummary.sampleCount, 0);
      expect(engine.sessionSummary.stabilityScore, isNull);
    });
  });
}
