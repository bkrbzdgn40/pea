import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/alternating_rep_engine.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/generic_rep_engine.dart';

void main() {
  group('AlternatingRepEngine', () {
    test('tracks left and right repetitions independently', () {
      final clock = _AlternatingRepTestClock();
      final engine = _buildEngine(clock);

      _completeLeftRep(engine, clock, peak: 100);
      _completeRightRep(engine, clock, peak: 95);

      expect(engine.totalRepCount, 2);
      expect(engine.leftRepCount, 1);
      expect(engine.rightRepCount, 1);
      expect(engine.repCountDifference, 0);
      expect(engine.lastCompletedSide, AlternatingRepSide.right);
    });

    test('locks the active side until its repetition completes', () {
      final clock = _AlternatingRepTestClock();
      final engine = _buildEngine(clock);

      _confirmBothNeutral(engine, clock);
      _confirmFrame(engine, clock, left: 135, right: 170, advanceMs: 100);

      expect(engine.activeSide, AlternatingRepSide.left);

      // Right-side movement cannot steal ownership while left is active.
      _confirmFrame(engine, clock, left: 100, right: 90, advanceMs: 100);
      expect(engine.activeSide, AlternatingRepSide.left);
      expect(engine.rightRepCount, 0);
    });

    test('records side-specific ROM and tempo averages', () {
      final clock = _AlternatingRepTestClock();
      final engine = _buildEngine(clock);

      _completeLeftRep(engine, clock, peak: 100);
      _completeLeftRep(engine, clock, peak: 90);
      _completeRightRep(engine, clock, peak: 110);

      expect(engine.leftRepCount, 2);
      expect(engine.rightRepCount, 1);
      expect(engine.leftAverageRom, greaterThan(0));
      expect(engine.rightAverageRom, greaterThan(0));
      expect(engine.leftAverageTempo, greaterThan(Duration.zero));
      expect(engine.rightAverageTempo, greaterThan(Duration.zero));
      expect(engine.averageRomDifference, greaterThanOrEqualTo(0));
      expect(
        engine.averageTempoDifference,
        greaterThanOrEqualTo(Duration.zero),
      );
    });

    test('uses observation time instead of processing completion time', () {
      final processingClock = _AlternatingRepTestClock();
      final engine = AlternatingRepEngine(
        repConfig: const GenericRepEngineConfig(
          neutralThreshold: 160,
          activeThreshold: 145,
          peakThreshold: 115,
          minimumRom: 20,
          activeConfirmationDuration: Duration.zero,
          peakConfirmationDuration: Duration.zero,
          returnConfirmationDuration: Duration.zero,
          initialNeutralConfirmationDuration: Duration.zero,
          neutralConfirmationDuration: Duration.zero,
        ),
        now: processingClock.now,
      );
      final base = DateTime.utc(2026, 7, 31, 8);

      engine.update(
        leftPrimaryMetric: 170,
        rightPrimaryMetric: 170,
        observedAt: base,
      );
      engine.update(
        leftPrimaryMetric: 135,
        rightPrimaryMetric: 170,
        observedAt: base.add(const Duration(milliseconds: 200)),
      );
      engine.update(
        leftPrimaryMetric: 100,
        rightPrimaryMetric: 170,
        observedAt: base.add(const Duration(milliseconds: 500)),
      );
      engine.update(
        leftPrimaryMetric: 130,
        rightPrimaryMetric: 170,
        observedAt: base.add(const Duration(milliseconds: 650)),
      );
      final result = engine.update(
        leftPrimaryMetric: 170,
        rightPrimaryMetric: 170,
        observedAt: base.add(const Duration(milliseconds: 900)),
      );

      final tempo = result.completedRep?.tempoBreakdown;
      expect(result.completedRep, isNotNull);
      expect(tempo, isNotNull);
      final completedTempo = tempo!;
      expect(
        completedTempo.towardPeakDuration,
        const Duration(milliseconds: 300),
      );
      expect(completedTempo.returnDuration, const Duration(milliseconds: 250));
      expect(
        completedTempo.totalRepDuration,
        const Duration(milliseconds: 700),
      );
      expect(processingClock.now(), DateTime(2026, 1, 1, 12));
    });

    test('reports the side and tempo for a completed repetition', () {
      final clock = _AlternatingRepTestClock();
      final engine = _buildEngine(clock);

      final completed = _completeLeftRep(engine, clock, peak: 100);

      expect(completed.side, AlternatingRepSide.left);
      expect(completed.sideRepIndex, 1);
      expect(completed.totalRepIndex, 1);
      expect(completed.rom, greaterThan(0));
      expect(completed.tempo, greaterThan(Duration.zero));
      expect(completed.tempoBreakdown, isNotNull);
      expect(completed.tempo, completed.tempoBreakdown!.totalRepDuration);
      expect(engine.tempoSessionSummary.repCount, 1);
      expect(engine.leftTempoSessionSummary.repCount, 1);
      expect(engine.rightTempoSessionSummary.repCount, 0);
    });

    test('feeds completed side reps into the shared symmetry engine', () {
      final clock = _AlternatingRepTestClock();
      final engine = _buildEngine(clock);

      final left = _completeLeftRep(engine, clock, peak: 100);
      final afterLeft = engine.symmetrySessionSummary;

      expect(left.symmetryComparison, isNull);
      expect(afterLeft.leftRepCount, 1);
      expect(afterLeft.rightRepCount, 0);
      expect(afterLeft.romSymmetryScore, isNull);
      expect(afterLeft.tempoSymmetryScore, isNull);

      final right = _completeRightRep(engine, clock, peak: 95);
      final comparison = right.symmetryComparison;
      final summary = engine.symmetrySessionSummary;

      expect(comparison, isNotNull);
      expect(comparison!.pairIndex, 1);
      expect(engine.lastCompletedSymmetryPair, same(comparison));
      expect(summary.leftRepCount, 1);
      expect(summary.rightRepCount, 1);
      expect(summary.pairedRepCount, 1);
      expect(summary.repCountSymmetryScore, 100);
      expect(summary.romSymmetryScore, isNotNull);
      expect(summary.tempoSymmetryScore, isNotNull);
      expect(summary.overallSymmetryScore, isNotNull);
    });

    test(
      'interrupt clears only active context and preserves completed stats',
      () {
        final clock = _AlternatingRepTestClock();
        final engine = _buildEngine(clock);

        _completeLeftRep(engine, clock, peak: 100);
        _confirmBothNeutral(engine, clock);
        _confirmFrame(engine, clock, left: 170, right: 135, advanceMs: 100);
        expect(engine.activeSide, AlternatingRepSide.right);

        engine.interrupt();

        expect(engine.activeSide, isNull);
        expect(engine.leftRepCount, 1);
        expect(engine.rightRepCount, 0);
        expect(engine.totalRepCount, 1);
      },
    );

    test('reset clears side counts, averages, and active side', () {
      final clock = _AlternatingRepTestClock();
      final engine = _buildEngine(clock);

      _completeLeftRep(engine, clock, peak: 100);
      _completeRightRep(engine, clock, peak: 100);

      engine.reset();

      expect(engine.activeSide, isNull);
      expect(engine.lastCompletedSide, isNull);
      expect(engine.totalRepCount, 0);
      expect(engine.leftRepCount, 0);
      expect(engine.rightRepCount, 0);
      expect(engine.leftAverageRom, 0);
      expect(engine.rightAverageTempo, Duration.zero);
      expect(engine.lastCompletedSymmetryPair, isNull);
      expect(engine.symmetrySessionSummary.overallSymmetryScore, isNull);
    });
  });
}

AlternatingRepEngine _buildEngine(_AlternatingRepTestClock clock) {
  return AlternatingRepEngine(
    repConfig: const GenericRepEngineConfig(
      neutralThreshold: 160,
      activeThreshold: 145,
      peakThreshold: 115,
      minimumRom: 20,
    ),
    now: clock.now,
  );
}

AlternatingRepCompletedRep _completeLeftRep(
  AlternatingRepEngine engine,
  _AlternatingRepTestClock clock, {
  required double peak,
}) {
  _confirmBothNeutral(engine, clock);
  _confirmFrame(engine, clock, left: 135, right: 170, advanceMs: 100);
  _confirmFrame(engine, clock, left: peak, right: 170, advanceMs: 100);
  _confirmFrame(engine, clock, left: 130, right: 170, advanceMs: 100);
  final result = _confirmFrame(
    engine,
    clock,
    left: 170,
    right: 170,
    advanceMs: 120,
  );
  return result.completedRep!;
}

AlternatingRepCompletedRep _completeRightRep(
  AlternatingRepEngine engine,
  _AlternatingRepTestClock clock, {
  required double peak,
}) {
  _confirmBothNeutral(engine, clock);
  _confirmFrame(engine, clock, left: 170, right: 135, advanceMs: 100);
  _confirmFrame(engine, clock, left: 170, right: peak, advanceMs: 100);
  _confirmFrame(engine, clock, left: 170, right: 130, advanceMs: 100);
  final result = _confirmFrame(
    engine,
    clock,
    left: 170,
    right: 170,
    advanceMs: 120,
  );
  return result.completedRep!;
}

void _confirmBothNeutral(
  AlternatingRepEngine engine,
  _AlternatingRepTestClock clock,
) {
  _confirmFrame(engine, clock, left: 170, right: 170, advanceMs: 120);
}

AlternatingRepEngineFrameResult _confirmFrame(
  AlternatingRepEngine engine,
  _AlternatingRepTestClock clock, {
  required double left,
  required double right,
  required int advanceMs,
}) {
  engine.update(leftPrimaryMetric: left, rightPrimaryMetric: right);
  clock.advance(Duration(milliseconds: advanceMs));
  return engine.update(leftPrimaryMetric: left, rightPrimaryMetric: right);
}

class _AlternatingRepTestClock {
  DateTime _current = DateTime(2026, 1, 1, 12);

  DateTime now() => _current;

  void advance(Duration duration) {
    _current = _current.add(duration);
  }
}
