import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/legacy_range_rep_scorer.dart';

void main() {
  group('LegacyRangeRepScorer', () {
    const scorer = LegacyRangeRepScorer();

    group('calculateRomScore', () {
      test('returns 100 at the target angle', () {
        expect(scorer.calculateRomScore(minAngle: 70, targetMinAngle: 70), 100);
      });

      test('applies the existing linear reduction above the target', () {
        expect(scorer.calculateRomScore(minAngle: 90, targetMinAngle: 70), 80);
      });

      test('clamps a sufficiently poor angle to zero', () {
        expect(scorer.calculateRomScore(minAngle: 200, targetMinAngle: 70), 0);
      });

      test('clamps an angle below the target to 100', () {
        expect(scorer.calculateRomScore(minAngle: 60, targetMinAngle: 70), 100);
      });
    });

    group('calculateTempoScore', () {
      test('returns 100 at the ideal duration', () {
        expect(
          scorer.calculateTempoScore(
            actualSeconds: 1,
            idealSeconds: 1,
            tempoPenaltyPerSecond: 20,
          ),
          100,
        );
      });

      test('penalizes equal positive and negative deviations equally', () {
        final fasterScore = scorer.calculateTempoScore(
          actualSeconds: 0.5,
          idealSeconds: 1,
          tempoPenaltyPerSecond: 20,
        );
        final slowerScore = scorer.calculateTempoScore(
          actualSeconds: 1.5,
          idealSeconds: 1,
          tempoPenaltyPerSecond: 20,
        );

        expect(fasterScore, 90);
        expect(slowerScore, fasterScore);
      });

      test('clamps a sufficiently large deviation to zero', () {
        expect(
          scorer.calculateTempoScore(
            actualSeconds: 10,
            idealSeconds: 1,
            tempoPenaltyPerSecond: 20,
          ),
          0,
        );
      });
    });

    group('calculateWeightedBaseScore', () {
      test('returns the arithmetic mean for equal positive weights', () {
        expect(
          scorer.calculateWeightedBaseScore(
            depthScore: 90,
            descentControlScore: 60,
            ascentControlScore: 30,
            depthWeight: 1,
            descentControlWeight: 1,
            ascentControlWeight: 1,
          ),
          60,
        );
      });

      test('returns the weighted mean for unequal positive weights', () {
        expect(
          scorer.calculateWeightedBaseScore(
            depthScore: 100,
            descentControlScore: 80,
            ascentControlScore: 60,
            depthWeight: 2,
            descentControlWeight: 1,
            ascentControlWeight: 1,
          ),
          85,
        );
      });

      test('ignores a component with zero weight', () {
        expect(
          scorer.calculateWeightedBaseScore(
            depthScore: 100,
            descentControlScore: 80,
            ascentControlScore: 60,
            depthWeight: 0,
            descentControlWeight: 1,
            ascentControlWeight: 1,
          ),
          70,
        );
      });

      test('ignores a component with negative weight', () {
        expect(
          scorer.calculateWeightedBaseScore(
            depthScore: 100,
            descentControlScore: 80,
            ascentControlScore: 60,
            depthWeight: -1,
            descentControlWeight: 1,
            ascentControlWeight: 1,
          ),
          70,
        );
      });

      test('returns null when all weights are non-positive', () {
        expect(
          scorer.calculateWeightedBaseScore(
            depthScore: 100,
            descentControlScore: 80,
            ascentControlScore: 60,
            depthWeight: 0,
            descentControlWeight: -1,
            ascentControlWeight: 0,
          ),
          isNull,
        );
      });
    });

    group('calculateBaseScore', () {
      test('uses the legacy average without a weighted score', () {
        expect(
          scorer.calculateBaseScore(
            romScore: 80,
            tempoScore: 60,
            weightedBaseScore: null,
            hadFormViolation: false,
          ),
          70,
        );
      });

      test('halves the legacy average for a form violation', () {
        expect(
          scorer.calculateBaseScore(
            romScore: 80,
            tempoScore: 60,
            weightedBaseScore: null,
            hadFormViolation: true,
          ),
          35,
        );
      });

      test('uses a weighted score unchanged without a form violation', () {
        expect(
          scorer.calculateBaseScore(
            romScore: 80,
            tempoScore: 60,
            weightedBaseScore: 75,
            hadFormViolation: false,
          ),
          75,
        );
      });

      test('halves a weighted score for a form violation', () {
        expect(
          scorer.calculateBaseScore(
            romScore: 80,
            tempoScore: 60,
            weightedBaseScore: 75,
            hadFormViolation: true,
          ),
          37.5,
        );
      });

      test('uses a non-null weighted score of zero', () {
        expect(
          scorer.calculateBaseScore(
            romScore: 80,
            tempoScore: 60,
            weightedBaseScore: 0,
            hadFormViolation: false,
          ),
          0,
        );
      });
    });
  });
}
