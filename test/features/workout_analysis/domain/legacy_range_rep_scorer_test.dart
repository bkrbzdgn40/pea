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
  });
}
