import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/generic_rep_engine.dart';

void main() {
  group('GenericRepEngine', () {
    test(
      'counts a decreasing-to-peak repetition through the full lifecycle',
      () {
        final clock = _Clock();
        final engine = GenericRepEngine(
          config: const GenericRepEngineConfig(
            neutralThreshold: 160,
            activeThreshold: 150,
            peakThreshold: 95,
          ),
          now: clock.now,
        );

        _confirm(clock, engine, 170, 120);
        expect(engine.isArmed, isTrue);
        expect(engine.phase, GenericRepPhase.neutral);

        _confirm(clock, engine, 140, 100);
        expect(engine.phase, GenericRepPhase.towardPeak);

        _confirm(clock, engine, 90, 100);
        expect(engine.phase, GenericRepPhase.peak);

        _confirm(clock, engine, 110, 100);
        expect(engine.phase, GenericRepPhase.returning);

        final result = _confirm(clock, engine, 170, 120);
        expect(engine.phase, GenericRepPhase.neutral);
        expect(engine.repCount, 1);
        expect(result.completedRep, isNotNull);
        expect(result.completedRep!.rom, closeTo(50, 0.001));
      },
    );

    test(
      'preserves the first active-crossing metric across confirmation lag',
      () {
        final clock = _Clock();
        final engine = GenericRepEngine(
          config: const GenericRepEngineConfig(
            neutralThreshold: 160,
            activeThreshold: 145,
            peakThreshold: 115,
            minimumRom: 20,
          ),
          now: clock.now,
        );

        _confirm(clock, engine, 170, 120);

        engine.update(primaryMetric: 140);
        clock.advance(const Duration(milliseconds: 100));
        final started = engine.update(primaryMetric: 108);

        expect(started.repStarted, isTrue);
        expect(engine.phase, GenericRepPhase.towardPeak);

        _confirm(clock, engine, 90, 100);
        _confirm(clock, engine, 130, 100);
        final completed = _confirm(clock, engine, 170, 120);

        expect(engine.repCount, 1);
        expect(completed.completedRep, isNotNull);
        expect(completed.completedRep!.startMetric, 140);
        expect(completed.completedRep!.peakMetric, 90);
        expect(completed.completedRep!.rom, 50);
      },
    );

    test(
      'preserves the first active crossing for increasing-to-peak movement',
      () {
        final clock = _Clock();
        final engine = GenericRepEngine(
          config: const GenericRepEngineConfig(
            neutralThreshold: 20,
            activeThreshold: 35,
            peakThreshold: 80,
            direction: GenericRepMetricDirection.increasingToPeak,
            minimumRom: 20,
          ),
          now: clock.now,
        );

        _confirm(clock, engine, 10, 120);

        engine.update(primaryMetric: 40);
        clock.advance(const Duration(milliseconds: 100));
        final started = engine.update(primaryMetric: 72);

        expect(started.repStarted, isTrue);
        expect(engine.phase, GenericRepPhase.towardPeak);

        _confirm(clock, engine, 90, 100);
        _confirm(clock, engine, 65, 100);
        final completed = _confirm(clock, engine, 10, 120);

        expect(engine.repCount, 1);
        expect(completed.completedRep, isNotNull);
        expect(completed.completedRep!.startMetric, 40);
        expect(completed.completedRep!.peakMetric, 90);
        expect(completed.completedRep!.rom, 50);
      },
    );

    test(
      'supports increasing-to-peak movement with the same state machine',
      () {
        final clock = _Clock();
        final engine = GenericRepEngine(
          config: const GenericRepEngineConfig(
            neutralThreshold: 20,
            activeThreshold: 35,
            peakThreshold: 80,
            direction: GenericRepMetricDirection.increasingToPeak,
          ),
          now: clock.now,
        );

        _confirm(clock, engine, 10, 120);
        _confirm(clock, engine, 45, 100);
        _confirm(clock, engine, 90, 100);
        _confirm(clock, engine, 65, 100);
        final result = _confirm(clock, engine, 10, 120);

        expect(engine.repCount, 1);
        expect(result.completedRep, isNotNull);
        expect(result.completedRep!.rom, closeTo(45, 0.001));
      },
    );

    test('debounce is cancelled when the transition condition is lost', () {
      final clock = _Clock();
      final engine = GenericRepEngine(
        config: const GenericRepEngineConfig(
          neutralThreshold: 160,
          activeThreshold: 150,
          peakThreshold: 95,
        ),
        now: clock.now,
      );

      engine.update(primaryMetric: 170);
      clock.advance(const Duration(milliseconds: 50));
      engine.update(primaryMetric: 140);

      expect(engine.isArmed, isFalse);
      expect(engine.pendingTransition, isNull);

      engine.update(primaryMetric: 170);
      clock.advance(const Duration(milliseconds: 120));
      engine.update(primaryMetric: 170);

      expect(engine.isArmed, isTrue);
    });

    test('rejects a completed lifecycle below the configured minimum ROM', () {
      final clock = _Clock();
      final engine = GenericRepEngine(
        config: const GenericRepEngineConfig(
          neutralThreshold: 160,
          activeThreshold: 150,
          peakThreshold: 145,
          activeEntryMargin: 0,
          peakEntryMargin: 0,
          peakExitMargin: 1,
          minimumRom: 10,
        ),
        now: clock.now,
      );

      _confirm(clock, engine, 170, 120);
      _confirm(clock, engine, 149, 100);
      _confirm(clock, engine, 144, 100);
      _confirm(clock, engine, 147, 100);
      final result = _confirm(clock, engine, 170, 120);

      expect(engine.repCount, 0);
      expect(result.repAborted, isTrue);
      expect(result.completedRep, isNull);
      expect(engine.phase, GenericRepPhase.neutral);
    });

    test(
      'an aborted partial repetition returns to neutral without counting',
      () {
        final clock = _Clock();
        final engine = GenericRepEngine(
          config: const GenericRepEngineConfig(
            neutralThreshold: 160,
            activeThreshold: 150,
            peakThreshold: 95,
          ),
          now: clock.now,
        );

        _confirm(clock, engine, 170, 120);
        _confirm(clock, engine, 140, 100);
        final result = _confirm(clock, engine, 170, 120);

        expect(result.repAborted, isTrue);
        expect(engine.repCount, 0);
        expect(engine.phase, GenericRepPhase.neutral);
      },
    );

    test(
      'reset clears repetition history and requires neutral acquisition again',
      () {
        final clock = _Clock();
        final engine = GenericRepEngine(
          config: const GenericRepEngineConfig(
            neutralThreshold: 160,
            activeThreshold: 150,
            peakThreshold: 95,
          ),
          now: clock.now,
        );

        _confirm(clock, engine, 170, 120);
        _confirm(clock, engine, 140, 100);
        _confirm(clock, engine, 90, 100);
        _confirm(clock, engine, 110, 100);
        _confirm(clock, engine, 170, 120);
        expect(engine.repCount, 1);

        engine.reset();

        expect(engine.repCount, 0);
        expect(engine.isArmed, isFalse);
        expect(engine.phase, GenericRepPhase.neutral);
      },
    );
  });
}

GenericRepEngineFrameResult _confirm(
  _Clock clock,
  GenericRepEngine engine,
  double metric,
  int milliseconds,
) {
  engine.update(primaryMetric: metric);
  clock.advance(Duration(milliseconds: milliseconds));
  return engine.update(primaryMetric: metric);
}

class _Clock {
  DateTime value = DateTime(2026, 1, 1);

  DateTime now() => value;

  void advance(Duration duration) {
    value = value.add(duration);
  }
}
