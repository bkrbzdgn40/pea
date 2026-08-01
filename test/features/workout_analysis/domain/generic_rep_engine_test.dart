import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/generic_rep_engine.dart';

void main() {
  group('GenericRepEngine', () {
    test('rejects a negative retained peak evidence window at runtime', () {
      expect(
        () => GenericRepEngine(
          config: const GenericRepEngineConfig(
            neutralThreshold: 160,
            activeThreshold: 150,
            peakThreshold: 95,
            retainedPeakEvidenceMaxAge: Duration(milliseconds: -1),
          ),
        ),
        throwsArgumentError,
      );
    });

    test('rejects a negative initial neutral confirmation window', () {
      expect(
        () => GenericRepEngine(
          config: const GenericRepEngineConfig(
            neutralThreshold: 160,
            activeThreshold: 150,
            peakThreshold: 95,
            initialNeutralConfirmationDuration: Duration(milliseconds: -1),
          ),
        ),
        throwsArgumentError,
      );
    });

    test('rejects negative return and neutral confirmation windows', () {
      expect(
        () => GenericRepEngine(
          config: const GenericRepEngineConfig(
            neutralThreshold: 160,
            activeThreshold: 150,
            peakThreshold: 95,
            returnConfirmationDuration: Duration(milliseconds: -1),
          ),
        ),
        throwsArgumentError,
      );
      expect(
        () => GenericRepEngine(
          config: const GenericRepEngineConfig(
            neutralThreshold: 160,
            activeThreshold: 150,
            peakThreshold: 95,
            neutralConfirmationDuration: Duration(milliseconds: -1),
          ),
        ),
        throwsArgumentError,
      );
    });

    test('rejects a negative neutral baseline window', () {
      expect(
        () => GenericRepEngine(
          config: const GenericRepEngineConfig(
            neutralThreshold: 160,
            activeThreshold: 150,
            peakThreshold: 95,
            neutralBaselineWindow: Duration(milliseconds: -1),
          ),
        ),
        throwsArgumentError,
      );
    });

    test('uses a longer confirmation only for initial neutral acquisition', () {
      final clock = _Clock();
      final engine = GenericRepEngine(
        config: const GenericRepEngineConfig(
          neutralThreshold: 20,
          activeThreshold: 35,
          peakThreshold: 80,
          direction: GenericRepMetricDirection.increasingToPeak,
          initialNeutralConfirmationDuration: Duration(milliseconds: 600),
          neutralConfirmationDuration: Duration(milliseconds: 100),
        ),
        now: clock.now,
      );

      engine.update(primaryMetric: 10);
      clock.advance(const Duration(milliseconds: 120));
      engine.update(primaryMetric: 10);
      expect(engine.isArmed, isFalse);

      clock.advance(const Duration(milliseconds: 480));
      engine.update(primaryMetric: 10);
      expect(engine.isArmed, isTrue);

      _confirm(clock, engine, 45, 100);
      _confirm(clock, engine, 90, 100);
      _confirm(clock, engine, 65, 100);
      final completed = _confirm(clock, engine, 10, 120);

      expect(engine.repCount, 1);
      expect(completed.completedRep, isNotNull);
    });

    test(
      'zero-duration return and neutral confirmations accept one matching frame',
      () {
        final clock = _Clock();
        final engine = GenericRepEngine(
          config: const GenericRepEngineConfig(
            neutralThreshold: 20,
            activeThreshold: 55,
            peakThreshold: 120,
            direction: GenericRepMetricDirection.increasingToPeak,
            peakEntryMargin: 0,
            returnConfirmationDuration: Duration.zero,
            neutralConfirmationDuration: Duration.zero,
          ),
          now: clock.now,
        );

        _confirm(clock, engine, 10, 120);
        _confirm(clock, engine, 70, 100);
        _confirm(clock, engine, 125, 100);

        final returning = engine.update(primaryMetric: 100);
        expect(
          returning.confirmedTransition?.type,
          GenericRepTransitionType.startReturning,
        );
        expect(engine.phase, GenericRepPhase.returning);

        final completed = engine.update(primaryMetric: 10);
        expect(
          completed.confirmedTransition?.type,
          GenericRepTransitionType.completeRep,
        );
        expect(completed.completedRep, isNotNull);
        expect(engine.repCount, 1);
      },
    );

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
      'uses an opt-in finish threshold without relaxing initial neutral',
      () {
        final clock = _Clock();
        final engine = GenericRepEngine(
          config: const GenericRepEngineConfig(
            neutralThreshold: 160,
            activeThreshold: 145,
            peakThreshold: 105,
            completionThreshold: 155,
          ),
          now: clock.now,
        );

        _confirm(clock, engine, 155, 120);
        expect(engine.isArmed, isFalse);

        _confirm(clock, engine, 170, 120);
        expect(engine.isArmed, isTrue);

        _confirm(clock, engine, 140, 100);
        _confirm(clock, engine, 90, 100);
        _confirm(clock, engine, 120, 100);

        final belowFinish = _confirm(clock, engine, 154, 120);
        expect(engine.repCount, 0);
        expect(engine.phase, GenericRepPhase.returning);
        expect(belowFinish.completedRep, isNull);

        final completed = _confirm(clock, engine, 155, 120);
        expect(engine.repCount, 1);
        expect(engine.phase, GenericRepPhase.neutral);
        expect(completed.completedRep, isNotNull);
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

    test(
      'pending peak confirmation survives release inside peak hysteresis',
      () {
        final clock = _Clock();
        final engine = GenericRepEngine(
          config: const GenericRepEngineConfig(
            neutralThreshold: 160,
            activeThreshold: 145,
            peakThreshold: 105,
            peakEntryMargin: 0,
            peakExitMargin: 8,
          ),
          now: clock.now,
        );

        _confirm(clock, engine, 170, 120);
        _confirm(clock, engine, 140, 100);

        final entry = engine.update(primaryMetric: 104);
        expect(entry.confirmedTransition, isNull);
        expect(engine.pendingTransition, GenericRepTransitionType.reachPeak);

        clock.advance(const Duration(milliseconds: 100));
        final confirmed = engine.update(primaryMetric: 110);

        expect(
          confirmed.confirmedTransition?.type,
          GenericRepTransitionType.reachPeak,
        );
        expect(engine.phase, GenericRepPhase.peak);
      },
    );

    test('pending peak confirmation cancels after exiting peak hysteresis', () {
      final clock = _Clock();
      final engine = GenericRepEngine(
        config: const GenericRepEngineConfig(
          neutralThreshold: 160,
          activeThreshold: 145,
          peakThreshold: 105,
          peakEntryMargin: 0,
          peakExitMargin: 8,
        ),
        now: clock.now,
      );

      _confirm(clock, engine, 170, 120);
      _confirm(clock, engine, 140, 100);

      engine.update(primaryMetric: 104);
      clock.advance(const Duration(milliseconds: 100));
      final result = engine.update(primaryMetric: 120);

      expect(result.confirmedTransition, isNull);
      expect(engine.pendingTransition, isNull);
      expect(engine.phase, GenericRepPhase.towardPeak);
    });

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
      'retains a sparse peak consumed by active-entry confirmation when enabled',
      () {
        final clock = _Clock();
        final engine = GenericRepEngine(
          config: const GenericRepEngineConfig(
            neutralThreshold: 160,
            activeThreshold: 150,
            peakThreshold: 95,
            retainPeakEvidenceAcrossActiveTransition: true,
          ),
          now: clock.now,
        );

        _confirm(clock, engine, 170, 120);

        engine.update(primaryMetric: 90);
        clock.advance(const Duration(milliseconds: 100));
        final started = engine.update(primaryMetric: 130);

        expect(started.repStarted, isTrue);
        expect(engine.phase, GenericRepPhase.towardPeak);
        expect(engine.pendingTransition, GenericRepTransitionType.reachPeak);

        clock.advance(const Duration(milliseconds: 20));
        final recoveredPeak = engine.update(primaryMetric: 130);

        expect(
          recoveredPeak.confirmedTransition?.type,
          GenericRepTransitionType.reachPeak,
        );
        expect(engine.phase, GenericRepPhase.peak);

        _confirm(clock, engine, 120, 100);
        final completed = _confirm(clock, engine, 170, 120);

        expect(engine.repCount, 1);
        expect(completed.completedRep, isNotNull);
        expect(completed.completedRep!.startMetric, 170);
        expect(completed.completedRep!.peakMetric, 90);
        expect(completed.completedRep!.rom, 80);
      },
    );

    test('expires retained peak evidence after the configured window', () {
      final clock = _Clock();
      final engine = GenericRepEngine(
        config: const GenericRepEngineConfig(
          neutralThreshold: 160,
          activeThreshold: 150,
          peakThreshold: 95,
          retainPeakEvidenceAcrossActiveTransition: true,
          retainedPeakEvidenceMaxAge: Duration(milliseconds: 200),
        ),
        now: clock.now,
      );

      _confirm(clock, engine, 170, 120);

      engine.update(primaryMetric: 90);
      clock.advance(const Duration(milliseconds: 300));
      final started = engine.update(primaryMetric: 130);

      expect(started.repStarted, isTrue);
      expect(engine.pendingTransition, isNull);

      final aborted = _confirm(clock, engine, 170, 120);

      expect(aborted.repAborted, isTrue);
      expect(engine.repCount, 0);
    });

    test('clears retained peak evidence when active entry is cancelled', () {
      final clock = _Clock();
      final engine = GenericRepEngine(
        config: const GenericRepEngineConfig(
          neutralThreshold: 160,
          activeThreshold: 150,
          peakThreshold: 95,
          retainPeakEvidenceAcrossActiveTransition: true,
        ),
        now: clock.now,
      );

      _confirm(clock, engine, 170, 120);

      engine.update(primaryMetric: 90);
      clock.advance(const Duration(milliseconds: 40));
      engine.update(primaryMetric: 170);

      engine.update(primaryMetric: 130);
      clock.advance(const Duration(milliseconds: 100));
      final started = engine.update(primaryMetric: 130);

      expect(started.repStarted, isTrue);
      expect(engine.pendingTransition, isNull);

      final aborted = _confirm(clock, engine, 170, 120);

      expect(aborted.repAborted, isTrue);
      expect(engine.repCount, 0);
    });

    test('keeps sparse-peak recovery disabled by default', () {
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

      engine.update(primaryMetric: 90);
      clock.advance(const Duration(milliseconds: 100));
      final started = engine.update(primaryMetric: 130);

      expect(started.repStarted, isTrue);
      expect(engine.pendingTransition, isNull);

      final aborted = _confirm(clock, engine, 170, 120);

      expect(aborted.repAborted, isTrue);
      expect(engine.repCount, 0);
      expect(engine.phase, GenericRepPhase.neutral);
    });

    test('recovers a decreasing sparse peak-to-neutral cycle', () {
      final clock = _Clock();
      final engine = GenericRepEngine(
        config: const GenericRepEngineConfig(
          neutralThreshold: 150,
          activeThreshold: 130,
          peakThreshold: 100,
          allowSparseCycleRecovery: true,
        ),
        now: clock.now,
      );

      _confirm(clock, engine, 165, 120);
      clock.advance(const Duration(milliseconds: 100));

      final peak = engine.update(primaryMetric: 93);

      expect(
        peak.confirmedTransitions.map((transition) => transition.type),
        <GenericRepTransitionType>[
          GenericRepTransitionType.startTowardPeak,
          GenericRepTransitionType.reachPeak,
        ],
      );
      expect(peak.repStarted, isTrue);
      expect(peak.usedSparseCycleRecovery, isTrue);
      expect(engine.phase, GenericRepPhase.peak);

      clock.advance(const Duration(milliseconds: 250));
      final completed = engine.update(primaryMetric: 165);

      expect(
        completed.confirmedTransitions.map((transition) => transition.type),
        <GenericRepTransitionType>[
          GenericRepTransitionType.startReturning,
          GenericRepTransitionType.completeRep,
        ],
      );
      expect(completed.completedRep, isNotNull);
      expect(completed.usedSparseCycleRecovery, isTrue);
      expect(completed.completedRep!.startMetric, 165);
      expect(completed.completedRep!.peakMetric, 93);
      expect(completed.completedRep!.rom, 72);
      expect(engine.repCount, 1);
      expect(engine.phase, GenericRepPhase.neutral);
    });

    test('recovers an increasing sparse peak-to-neutral cycle', () {
      final clock = _Clock();
      final engine = GenericRepEngine(
        config: const GenericRepEngineConfig(
          neutralThreshold: 20,
          activeThreshold: 55,
          peakThreshold: 135,
          direction: GenericRepMetricDirection.increasingToPeak,
          allowSparseCycleRecovery: true,
        ),
        now: clock.now,
      );

      _confirm(clock, engine, 10, 120);
      clock.advance(const Duration(milliseconds: 100));
      final peak = engine.update(primaryMetric: 145);

      expect(peak.repStarted, isTrue);
      expect(peak.usedSparseCycleRecovery, isTrue);
      expect(
        peak.confirmedTransition?.type,
        GenericRepTransitionType.reachPeak,
      );
      expect(engine.phase, GenericRepPhase.peak);

      clock.advance(const Duration(milliseconds: 250));
      final completed = engine.update(primaryMetric: 10);

      expect(completed.completedRep, isNotNull);
      expect(completed.usedSparseCycleRecovery, isTrue);
      expect(completed.completedRep!.startMetric, 10);
      expect(completed.completedRep!.peakMetric, 145);
      expect(completed.completedRep!.rom, 135);
      expect(engine.repCount, 1);
      expect(engine.phase, GenericRepPhase.neutral);
    });

    test('does not directly complete from stale sparse peak evidence', () {
      final clock = _Clock();
      final engine = GenericRepEngine(
        config: const GenericRepEngineConfig(
          neutralThreshold: 150,
          activeThreshold: 130,
          peakThreshold: 100,
          allowSparseCycleRecovery: true,
          retainedPeakEvidenceMaxAge: Duration(milliseconds: 750),
        ),
        now: clock.now,
      );

      _confirm(clock, engine, 165, 120);
      clock.advance(const Duration(milliseconds: 100));
      final peak = engine.update(primaryMetric: 93);
      expect(
        peak.confirmedTransition?.type,
        GenericRepTransitionType.reachPeak,
      );

      clock.advance(const Duration(milliseconds: 751));
      final staleNeutral = engine.update(primaryMetric: 165);

      expect(staleNeutral.completedRep, isNull);
      expect(staleNeutral.confirmedTransitions, isEmpty);
      expect(engine.repCount, 0);
    });

    test('does not chain a strict sparse cycle unless explicitly enabled', () {
      final clock = _Clock();
      final engine = GenericRepEngine(
        config: const GenericRepEngineConfig(
          neutralThreshold: 150,
          activeThreshold: 130,
          peakThreshold: 100,
        ),
        now: clock.now,
      );

      _confirm(clock, engine, 165, 120);
      clock.advance(const Duration(milliseconds: 100));
      final peak = engine.update(primaryMetric: 93);
      clock.advance(const Duration(milliseconds: 250));
      final neutral = engine.update(primaryMetric: 165);

      expect(peak.confirmedTransitions, isEmpty);
      expect(neutral.completedRep, isNull);
      expect(engine.repCount, 0);
    });

    test('uses an opt-in median neutral baseline for increasing movements', () {
      final clock = _Clock();
      final engine = GenericRepEngine(
        config: const GenericRepEngineConfig(
          neutralThreshold: 120,
          activeThreshold: 121,
          peakThreshold: 122,
          direction: GenericRepMetricDirection.increasingToPeak,
          activeEntryMargin: 0,
          peakEntryMargin: 0,
          peakExitMargin: 1,
          retainPeakEvidenceAcrossActiveTransition: true,
          neutralBaselineWindow: Duration(milliseconds: 1500),
          neutralBaselineThresholdMargin: 2,
        ),
        now: clock.now,
      );

      _confirm(clock, engine, 110, 120);
      engine.update(primaryMetric: 117);
      clock.advance(const Duration(milliseconds: 250));
      engine.update(primaryMetric: 123);
      clock.advance(const Duration(milliseconds: 50));
      engine.update(primaryMetric: 121);
      clock.advance(const Duration(milliseconds: 250));
      engine.update(primaryMetric: 120);
      clock.advance(const Duration(milliseconds: 250));
      engine.update(primaryMetric: 124);
      clock.advance(const Duration(milliseconds: 100));
      engine.update(primaryMetric: 125);
      clock.advance(const Duration(milliseconds: 100));
      engine.update(primaryMetric: 125);
      clock.advance(const Duration(milliseconds: 100));
      engine.update(primaryMetric: 120);
      clock.advance(const Duration(milliseconds: 100));
      engine.update(primaryMetric: 120);
      clock.advance(const Duration(milliseconds: 120));
      engine.update(primaryMetric: 110);
      clock.advance(const Duration(milliseconds: 120));
      final completed = engine.update(primaryMetric: 110);

      expect(engine.repCount, 1);
      expect(completed.completedRep, isNotNull);
      expect(completed.completedRep!.startMetric, 110.0);
      expect(completed.completedRep!.peakMetric, 125.0);
      expect(completed.completedRep!.rom, 15.0);
    });

    test('explicit observation time drives lifecycle timing', () {
      final fixedProcessingClock = _Clock();
      final engine = GenericRepEngine(
        config: const GenericRepEngineConfig(
          neutralThreshold: 160,
          activeThreshold: 150,
          peakThreshold: 95,
          activeConfirmationDuration: Duration.zero,
          peakConfirmationDuration: Duration.zero,
          returnConfirmationDuration: Duration.zero,
          initialNeutralConfirmationDuration: Duration.zero,
          neutralConfirmationDuration: Duration.zero,
        ),
        now: fixedProcessingClock.now,
      );
      final base = DateTime.utc(2026, 7, 31, 8);

      final acquired = engine.update(primaryMetric: 170, observedAt: base);
      final started = engine.update(
        primaryMetric: 140,
        observedAt: base.add(const Duration(milliseconds: 200)),
      );
      final peaked = engine.update(
        primaryMetric: 90,
        observedAt: base.add(const Duration(milliseconds: 500)),
      );
      final returning = engine.update(
        primaryMetric: 110,
        observedAt: base.add(const Duration(milliseconds: 650)),
      );
      final completed = engine.update(
        primaryMetric: 170,
        observedAt: base.add(const Duration(milliseconds: 900)),
      );

      expect(acquired.confirmedTransition?.effectiveAt, base);
      expect(
        started.confirmedTransition?.effectiveAt,
        base.add(const Duration(milliseconds: 200)),
      );
      expect(
        peaked.confirmedTransition?.effectiveAt,
        base.add(const Duration(milliseconds: 500)),
      );
      expect(
        returning.confirmedTransition?.effectiveAt,
        base.add(const Duration(milliseconds: 650)),
      );
      expect(
        completed.confirmedTransition?.effectiveAt,
        base.add(const Duration(milliseconds: 900)),
      );
      expect(completed.completedRep, isNotNull);
      expect(engine.repCount, 1);
    });

    test('rejects a non-monotonic observation without mutating lifecycle', () {
      final engine = GenericRepEngine(
        config: const GenericRepEngineConfig(
          neutralThreshold: 160,
          activeThreshold: 150,
          peakThreshold: 95,
          initialNeutralConfirmationDuration: Duration.zero,
        ),
      );
      final base = DateTime.utc(2026, 7, 31, 8);

      final acquired = engine.update(primaryMetric: 170, observedAt: base);
      final rejected = engine.update(
        primaryMetric: 140,
        observedAt: base.subtract(const Duration(milliseconds: 1)),
      );

      expect(acquired.observationAccepted, isTrue);
      expect(rejected.observationAccepted, isFalse);
      expect(rejected.observationIssue, 'nonMonotonicObservation');
      expect(engine.nonMonotonicObservationCount, 1);
      expect(engine.phase, GenericRepPhase.neutral);
      expect(engine.repCount, 0);
    });

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
