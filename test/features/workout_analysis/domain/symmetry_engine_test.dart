import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/symmetry_engine.dart';

void main() {
  group('SymmetryEngine', () {
    test('starts with an explicitly unmeasured empty summary', () {
      final engine = SymmetryEngine();

      final summary = engine.symmetrySessionSummary;

      expect(summary.leftRepCount, 0);
      expect(summary.rightRepCount, 0);
      expect(summary.pairedRepCount, 0);
      expect(summary.repCountSymmetryScore, isNull);
      expect(summary.romSymmetryScore, isNull);
      expect(summary.tempoSymmetryScore, isNull);
      expect(summary.overallSymmetryScore, isNull);
    });

    test('does not invent ROM or tempo symmetry when one side is missing', () {
      final engine = SymmetryEngine();

      final pair = engine.record(
        side: SymmetrySide.left,
        sideRepIndex: 1,
        rom: 40,
        tempo: const Duration(milliseconds: 1000),
      );
      final summary = engine.symmetrySessionSummary;

      expect(pair, isNull);
      expect(summary.leftRepCount, 1);
      expect(summary.rightRepCount, 0);
      expect(summary.repCountDifference, 1);
      expect(summary.repCountSymmetryScore, 0);
      expect(summary.leftAverageRom, 40);
      expect(summary.rightAverageRom, isNull);
      expect(summary.averageRomDifference, isNull);
      expect(summary.romSymmetryScore, isNull);
      expect(summary.averageTempoDifference, isNull);
      expect(summary.tempoSymmetryScore, isNull);
      expect(summary.overallSymmetryScore, isNull);
    });

    test('reports perfect symmetry for equal matched repetitions', () {
      final engine = SymmetryEngine();

      engine.record(
        side: SymmetrySide.left,
        sideRepIndex: 1,
        rom: 40,
        tempo: const Duration(milliseconds: 1000),
      );
      final pair = engine.record(
        side: SymmetrySide.right,
        sideRepIndex: 1,
        rom: 40,
        tempo: const Duration(milliseconds: 1000),
      );

      expect(pair, isNotNull);
      expect(pair!.pairIndex, 1);
      expect(pair.romDifference, 0);
      expect(pair.tempoDifference, Duration.zero);
      expect(pair.romSymmetryScore, 100);
      expect(pair.tempoSymmetryScore, 100);
      expect(pair.overallSymmetryScore, 100);
      expect(pair.overallAsymmetryScore, 0);

      final summary = engine.symmetrySessionSummary;
      expect(summary.pairedRepCount, 1);
      expect(summary.repCountSymmetryScore, 100);
      expect(summary.romSymmetryScore, 100);
      expect(summary.tempoSymmetryScore, 100);
      expect(summary.overallSymmetryScore, 100);
    });

    test('normalizes pair-level ROM and tempo differences to 0-100 scores', () {
      final engine = SymmetryEngine();

      engine.record(
        side: SymmetrySide.left,
        sideRepIndex: 1,
        rom: 40,
        tempo: const Duration(milliseconds: 1000),
      );
      final pair = engine.record(
        side: SymmetrySide.right,
        sideRepIndex: 1,
        rom: 30,
        tempo: const Duration(milliseconds: 800),
      )!;

      expect(pair.romDifference, 10);
      expect(pair.romSymmetryScore, 75);
      expect(pair.tempoDifference, const Duration(milliseconds: 200));
      expect(pair.tempoSymmetryScore, 80);
      expect(pair.overallSymmetryScore, 77.5);
      expect(pair.romAsymmetryScore, 25);
      expect(pair.tempoAsymmetryScore, 20);
      expect(pair.overallAsymmetryScore, 22.5);
    });

    test('aggregates rep balance, average ROM, and average tempo', () {
      final engine = SymmetryEngine();

      engine.record(
        side: SymmetrySide.left,
        sideRepIndex: 1,
        rom: 40,
        tempo: const Duration(milliseconds: 1000),
      );
      engine.record(
        side: SymmetrySide.right,
        sideRepIndex: 1,
        rom: 40,
        tempo: const Duration(milliseconds: 800),
      );
      engine.record(
        side: SymmetrySide.left,
        sideRepIndex: 2,
        rom: 50,
        tempo: const Duration(milliseconds: 1200),
      );

      final summary = engine.symmetrySessionSummary;

      expect(summary.leftRepCount, 2);
      expect(summary.rightRepCount, 1);
      expect(summary.pairedRepCount, 1);
      expect(summary.repCountDifference, 1);
      expect(summary.repCountSymmetryScore, 50);
      expect(summary.leftAverageRom, 45);
      expect(summary.rightAverageRom, 40);
      expect(summary.averageRomDifference, 5);
      expect(summary.romSymmetryScore, closeTo(88.8888, 0.001));
      expect(summary.leftAverageTempo, const Duration(milliseconds: 1100));
      expect(summary.rightAverageTempo, const Duration(milliseconds: 800));
      expect(summary.averageTempoDifference, const Duration(milliseconds: 300));
      expect(summary.tempoSymmetryScore, closeTo(72.7272, 0.001));
      expect(summary.overallSymmetryScore, closeTo(70.5387, 0.001));
      expect(summary.repCountAsymmetryScore, 50);
      expect(summary.romAsymmetryScore, closeTo(11.1111, 0.001));
      expect(summary.tempoAsymmetryScore, closeTo(27.2727, 0.001));
      expect(summary.overallAsymmetryScore, closeTo(29.4612, 0.001));
    });

    test(
      'matches repetitions by side index regardless of completion order',
      () {
        final engine = SymmetryEngine();

        final first = engine.record(
          side: SymmetrySide.right,
          sideRepIndex: 1,
          rom: 35,
          tempo: const Duration(milliseconds: 900),
        );
        final second = engine.record(
          side: SymmetrySide.left,
          sideRepIndex: 1,
          rom: 35,
          tempo: const Duration(milliseconds: 900),
        );

        expect(first, isNull);
        expect(second, isNotNull);
        expect(second!.pairIndex, 1);
        expect(engine.lastCompletedSymmetryPair, same(second));
      },
    );

    test('rejects duplicate samples for the same side rep index', () {
      final engine = SymmetryEngine();

      engine.record(
        side: SymmetrySide.left,
        sideRepIndex: 1,
        rom: 40,
        tempo: const Duration(milliseconds: 1000),
      );

      expect(
        () => engine.record(
          side: SymmetrySide.left,
          sideRepIndex: 1,
          rom: 42,
          tempo: const Duration(milliseconds: 1050),
        ),
        throwsStateError,
      );
    });

    test('reset clears pair and session symmetry state', () {
      final engine = SymmetryEngine();

      engine.record(
        side: SymmetrySide.left,
        sideRepIndex: 1,
        rom: 40,
        tempo: const Duration(milliseconds: 1000),
      );
      engine.record(
        side: SymmetrySide.right,
        sideRepIndex: 1,
        rom: 40,
        tempo: const Duration(milliseconds: 1000),
      );

      engine.reset();

      expect(engine.lastCompletedSymmetryPair, isNull);
      expect(engine.symmetrySessionSummary, same(SymmetrySessionSummary.empty));
    });
  });
}
