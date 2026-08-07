import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/challenges/domain/models/medal_thresholds.dart';
import 'package:pose_estimation_app/features/challenges/domain/models/medal_tier.dart';

void main() {
  group('MedalThresholds', () {
    final thresholds = MedalThresholds(bronze: 10, silver: 20, gold: 30);

    test('requires positive strictly increasing thresholds', () {
      expect(
        () => MedalThresholds(bronze: 0, silver: 20, gold: 30),
        throwsArgumentError,
      );
      expect(
        () => MedalThresholds(bronze: 10, silver: 10, gold: 30),
        throwsArgumentError,
      );
      expect(
        () => MedalThresholds(bronze: 10, silver: 20, gold: 20),
        throwsArgumentError,
      );
    });

    test('resolves medal tiers at exact boundaries', () {
      expect(thresholds.tierFor(9.99), MedalTier.none);
      expect(thresholds.tierFor(10), MedalTier.bronze);
      expect(thresholds.tierFor(19.99), MedalTier.bronze);
      expect(thresholds.tierFor(20), MedalTier.silver);
      expect(thresholds.tierFor(29.99), MedalTier.silver);
      expect(thresholds.tierFor(30), MedalTier.gold);
      expect(thresholds.tierFor(500), MedalTier.gold);
    });

    test('returns the next reachable tier and its threshold', () {
      expect(thresholds.nextTierFor(0), MedalTier.bronze);
      expect(thresholds.nextTierFor(10), MedalTier.silver);
      expect(thresholds.nextTierFor(20), MedalTier.gold);
      expect(thresholds.nextTierFor(30), isNull);
      expect(thresholds.thresholdFor(MedalTier.bronze), 10);
      expect(thresholds.thresholdFor(MedalTier.silver), 20);
      expect(thresholds.thresholdFor(MedalTier.gold), 30);
      expect(
        () => thresholds.thresholdFor(MedalTier.none),
        throwsArgumentError,
      );
    });

    test('non-finite or negative progress never earns a medal', () {
      expect(thresholds.tierFor(double.nan), MedalTier.none);
      expect(thresholds.tierFor(double.infinity), MedalTier.none);
      expect(thresholds.tierFor(-1), MedalTier.none);
    });
  });
}
