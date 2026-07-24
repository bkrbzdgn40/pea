import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/generic_rep_engine.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/tempo_engine.dart';

void main() {
  group('TempoEngine', () {
    test(
      'captures eccentric, pause, concentric, top-pause, and total tempo',
      () {
        final engine = TempoEngine();
        final base = DateTime(2026, 1, 1, 12);

        engine.process(
          _transition(GenericRepTransitionType.acquireNeutral, base),
        );
        engine.process(
          _transition(
            GenericRepTransitionType.startTowardPeak,
            base.add(const Duration(milliseconds: 200)),
          ),
        );
        engine.process(
          _transition(
            GenericRepTransitionType.reachPeak,
            base.add(const Duration(milliseconds: 1000)),
          ),
        );
        engine.process(
          _transition(
            GenericRepTransitionType.startReturning,
            base.add(const Duration(milliseconds: 1200)),
          ),
        );
        final completed = engine.process(
          _transition(
            GenericRepTransitionType.completeRep,
            base.add(const Duration(milliseconds: 1900)),
            completedRep: const GenericRepCompletedRep(
              repIndex: 1,
              startMetric: 170,
              peakMetric: 90,
              rom: 80,
            ),
          ),
        );

        expect(completed, isNotNull);
        expect(completed!.eccentricDuration.inMilliseconds, 800);
        expect(completed.bottomPauseDuration.inMilliseconds, 200);
        expect(completed.concentricDuration.inMilliseconds, 700);
        expect(completed.topPauseDuration.inMilliseconds, 200);
        expect(completed.totalRepDuration.inMilliseconds, 1700);
        expect(completed.towardPeakDuration.inMilliseconds, 800);
        expect(completed.returnDuration.inMilliseconds, 700);
      },
    );

    test('maps toward-peak phase to concentric action when configured', () {
      final engine = TempoEngine(
        towardPeakAction: TempoTowardPeakAction.concentric,
      );
      final base = DateTime(2026, 1, 1, 12);

      final completed = _completeRep(
        engine,
        base: base,
        repIndex: 1,
        towardPeakMs: 600,
        bottomPauseMs: 100,
        returnMs: 900,
      );

      expect(completed.concentricDuration.inMilliseconds, 600);
      expect(completed.eccentricDuration.inMilliseconds, 900);
    });

    test(
      'aggregates average, fastest, slowest, and consistency per session',
      () {
        final engine = TempoEngine();
        final base = DateTime(2026, 1, 1, 12);

        _completeRep(
          engine,
          base: base,
          repIndex: 1,
          towardPeakMs: 400,
          bottomPauseMs: 100,
          returnMs: 500,
        );
        _completeRep(
          engine,
          base: base.add(const Duration(seconds: 3)),
          repIndex: 2,
          towardPeakMs: 900,
          bottomPauseMs: 100,
          returnMs: 1000,
        );

        final summary = engine.sessionSummary;
        expect(summary.repCount, 2);
        expect(summary.averageRepDuration.inMilliseconds, 1500);
        expect(summary.fastestRepDuration.inMilliseconds, 1000);
        expect(summary.slowestRepDuration.inMilliseconds, 2000);
        expect(summary.consistencyScore, closeTo(66.666, 0.01));
      },
    );

    test('processes sparse chained transitions in chronological order', () {
      final engine = TempoEngine();
      final base = DateTime(2026, 1, 1, 12);

      engine.process(
        _transition(GenericRepTransitionType.acquireNeutral, base),
      );
      engine.process(
        _transitions(<GenericRepConfirmedTransition>[
          GenericRepConfirmedTransition(
            type: GenericRepTransitionType.startTowardPeak,
            effectiveAt: base.add(const Duration(milliseconds: 100)),
          ),
          GenericRepConfirmedTransition(
            type: GenericRepTransitionType.reachPeak,
            effectiveAt: base.add(const Duration(milliseconds: 350)),
          ),
        ], phaseAfterUpdate: GenericRepPhase.peak),
      );
      final completed = engine.process(
        _transitions(
          <GenericRepConfirmedTransition>[
            GenericRepConfirmedTransition(
              type: GenericRepTransitionType.startReturning,
              effectiveAt: base.add(const Duration(milliseconds: 350)),
            ),
            GenericRepConfirmedTransition(
              type: GenericRepTransitionType.completeRep,
              effectiveAt: base.add(const Duration(milliseconds: 650)),
            ),
          ],
          phaseAfterUpdate: GenericRepPhase.neutral,
          completedRep: const GenericRepCompletedRep(
            repIndex: 1,
            startMetric: 165,
            peakMetric: 93,
            rom: 72,
          ),
        ),
      );

      expect(completed, isNotNull);
      expect(completed!.towardPeakDuration.inMilliseconds, 250);
      expect(completed.bottomPauseDuration, Duration.zero);
      expect(completed.returnDuration.inMilliseconds, 300);
      expect(completed.totalRepDuration.inMilliseconds, 550);
      expect(engine.sessionSummary.repCount, 1);
    });

    test('does not record an aborted lifecycle as a completed tempo rep', () {
      final engine = TempoEngine();
      final base = DateTime(2026, 1, 1, 12);

      engine.process(
        _transition(GenericRepTransitionType.acquireNeutral, base),
      );
      engine.process(
        _transition(
          GenericRepTransitionType.startTowardPeak,
          base.add(const Duration(milliseconds: 200)),
        ),
      );
      engine.process(
        _transition(
          GenericRepTransitionType.abortToNeutral,
          base.add(const Duration(milliseconds: 700)),
        ),
      );

      expect(engine.lastCompletedRep, isNull);
      expect(engine.sessionSummary.repCount, 0);
    });

    test('shiftActiveTiming excludes a known visibility gap', () {
      final engine = TempoEngine();
      final base = DateTime(2026, 1, 1, 12);

      engine.process(
        _transition(GenericRepTransitionType.acquireNeutral, base),
      );
      engine.process(
        _transition(
          GenericRepTransitionType.startTowardPeak,
          base.add(const Duration(milliseconds: 100)),
        ),
      );
      engine.shiftActiveTiming(const Duration(milliseconds: 300));
      engine.process(
        _transition(
          GenericRepTransitionType.reachPeak,
          base.add(const Duration(milliseconds: 1000)),
        ),
      );
      engine.process(
        _transition(
          GenericRepTransitionType.startReturning,
          base.add(const Duration(milliseconds: 1100)),
        ),
      );
      final completed = engine.process(
        _transition(
          GenericRepTransitionType.completeRep,
          base.add(const Duration(milliseconds: 1700)),
          completedRep: const GenericRepCompletedRep(
            repIndex: 1,
            startMetric: 170,
            peakMetric: 90,
            rom: 80,
          ),
        ),
      );

      expect(completed!.towardPeakDuration.inMilliseconds, 600);
      expect(completed.totalRepDuration.inMilliseconds, 1300);
    });

    test('reset clears active timing and accumulated session tempo', () {
      final engine = TempoEngine();
      final base = DateTime(2026, 1, 1, 12);

      _completeRep(
        engine,
        base: base,
        repIndex: 1,
        towardPeakMs: 500,
        bottomPauseMs: 100,
        returnMs: 500,
      );
      expect(engine.sessionSummary.repCount, 1);

      engine.reset();

      expect(engine.lastCompletedRep, isNull);
      expect(engine.sessionSummary, same(TempoSessionSummary.empty));
    });
  });
}

TempoRepResult _completeRep(
  TempoEngine engine, {
  required DateTime base,
  required int repIndex,
  required int towardPeakMs,
  required int bottomPauseMs,
  required int returnMs,
}) {
  engine.process(_transition(GenericRepTransitionType.acquireNeutral, base));
  final startedAt = base.add(const Duration(milliseconds: 100));
  engine.process(
    _transition(GenericRepTransitionType.startTowardPeak, startedAt),
  );
  final peakAt = startedAt.add(Duration(milliseconds: towardPeakMs));
  engine.process(_transition(GenericRepTransitionType.reachPeak, peakAt));
  final returningAt = peakAt.add(Duration(milliseconds: bottomPauseMs));
  engine.process(
    _transition(GenericRepTransitionType.startReturning, returningAt),
  );
  final completedAt = returningAt.add(Duration(milliseconds: returnMs));
  return engine.process(
    _transition(
      GenericRepTransitionType.completeRep,
      completedAt,
      completedRep: GenericRepCompletedRep(
        repIndex: repIndex,
        startMetric: 170,
        peakMetric: 90,
        rom: 80,
      ),
    ),
  )!;
}

GenericRepEngineFrameResult _transition(
  GenericRepTransitionType type,
  DateTime effectiveAt, {
  GenericRepCompletedRep? completedRep,
}) {
  final phaseAfter = switch (type) {
    GenericRepTransitionType.acquireNeutral => GenericRepPhase.neutral,
    GenericRepTransitionType.startTowardPeak => GenericRepPhase.towardPeak,
    GenericRepTransitionType.reachPeak => GenericRepPhase.peak,
    GenericRepTransitionType.startReturning => GenericRepPhase.returning,
    GenericRepTransitionType.abortToNeutral => GenericRepPhase.neutral,
    GenericRepTransitionType.completeRep => GenericRepPhase.neutral,
  };

  return GenericRepEngineFrameResult(
    wasArmedAtFrameStart: true,
    isArmedAfterUpdate: true,
    phaseBeforeUpdate: GenericRepPhase.neutral,
    phaseAfterUpdate: phaseAfter,
    confirmedTransition: GenericRepConfirmedTransition(
      type: type,
      effectiveAt: effectiveAt,
    ),
    completedRep: completedRep,
  );
}

GenericRepEngineFrameResult _transitions(
  List<GenericRepConfirmedTransition> transitions, {
  required GenericRepPhase phaseAfterUpdate,
  GenericRepCompletedRep? completedRep,
}) {
  return GenericRepEngineFrameResult(
    wasArmedAtFrameStart: true,
    isArmedAfterUpdate: true,
    phaseBeforeUpdate: GenericRepPhase.neutral,
    phaseAfterUpdate: phaseAfterUpdate,
    confirmedTransitions: transitions,
    completedRep: completedRep,
  );
}
