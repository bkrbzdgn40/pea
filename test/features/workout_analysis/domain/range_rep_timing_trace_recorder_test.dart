import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/generic_rep_engine.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/range_rep_timing_trace.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/range_rep_timing_trace_recorder.dart';

void main() {
  group('RangeRepTimingTraceRecorder', () {
    test('finalizes one immutable completed timing snapshot', () {
      final recorder = RangeRepTimingTraceRecorder();
      final base = DateTime.utc(2026, 8, 1, 10);

      recorder.start();
      recorder.record(
        phase: GenericRepPhase.towardPeak,
        primaryMetric: 140,
        observedAt: base,
        processedAt: base.add(const Duration(milliseconds: 20)),
      );
      recorder.record(
        phase: GenericRepPhase.peak,
        primaryMetric: 90,
        observedAt: base.add(const Duration(milliseconds: 100)),
        processedAt: base.add(const Duration(milliseconds: 130)),
      );
      recorder.record(
        phase: GenericRepPhase.returning,
        primaryMetric: 150,
        observedAt: base.add(const Duration(milliseconds: 220)),
        processedAt: base.add(const Duration(milliseconds: 260)),
      );
      recorder.addTransitions(<GenericRepConfirmedTransition>[
        GenericRepConfirmedTransition(
          type: GenericRepTransitionType.startTowardPeak,
          effectiveAt: base,
          confirmedAt: base.add(const Duration(milliseconds: 80)),
        ),
        GenericRepConfirmedTransition(
          type: GenericRepTransitionType.reachPeak,
          effectiveAt: base.add(const Duration(milliseconds: 100)),
          confirmedAt: base.add(const Duration(milliseconds: 180)),
        ),
      ]);
      recorder.markVisibilityGap();

      final completed = recorder.finish(RangeRepTimingTraceOutcome.completed);

      expect(completed, isNotNull);
      expect(recorder.activeSnapshot, isNull);
      expect(recorder.lastEndedSnapshot, same(completed));
      expect(completed?.outcome, RangeRepTimingTraceOutcome.completed);
      expect(completed?.sampleCount, 3);
      expect(completed?.towardPeakSampleCount, 1);
      expect(completed?.peakSampleCount, 1);
      expect(completed?.returnSampleCount, 1);
      expect(completed?.averageObservationIntervalMs, closeTo(110, 0.001));
      expect(completed?.maxObservationIntervalMs, 120);
      expect(completed?.maxProcessingLagMs, 40);
      expect(completed?.directionChangeCount, 1);
      expect(completed?.hadVisibilityGap, isTrue);
      expect(completed?.transitions, hasLength(2));
      expect(
        () => completed?.transitions.add(
          RangeRepTimingTransitionTrace(
            type: GenericRepTransitionType.completeRep.name,
            effectiveAt: base,
            confirmedAt: base,
          ),
        ),
        throwsUnsupportedError,
      );
    });

    test('preserves the last ended trace while a new cycle is active', () {
      final recorder = RangeRepTimingTraceRecorder();
      final base = DateTime.utc(2026, 8, 1, 10);

      recorder.start();
      recorder.record(
        phase: GenericRepPhase.towardPeak,
        primaryMetric: 140,
        observedAt: base,
        processedAt: base,
      );
      final first = recorder.finish(RangeRepTimingTraceOutcome.aborted);

      recorder.start();
      recorder.record(
        phase: GenericRepPhase.towardPeak,
        primaryMetric: 130,
        observedAt: base.add(const Duration(seconds: 1)),
        processedAt: base.add(const Duration(seconds: 1)),
      );

      expect(
        recorder.activeSnapshot?.outcome,
        RangeRepTimingTraceOutcome.active,
      );
      expect(recorder.lastEndedSnapshot, same(first));

      recorder.reset();

      expect(recorder.activeSnapshot, isNull);
      expect(recorder.lastEndedSnapshot, isNull);
    });
  });
}
