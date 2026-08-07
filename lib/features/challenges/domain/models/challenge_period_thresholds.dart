import 'challenge_period.dart';
import 'medal_thresholds.dart';

/// Thresholds for all three supported calendar periods.
class ChallengePeriodThresholds {
  const ChallengePeriodThresholds({
    required this.daily,
    required this.weekly,
    required this.monthly,
  });

  final MedalThresholds daily;
  final MedalThresholds weekly;
  final MedalThresholds monthly;

  MedalThresholds forPeriod(ChallengePeriod period) {
    return switch (period) {
      ChallengePeriod.daily => daily,
      ChallengePeriod.weekly => weekly,
      ChallengePeriod.monthly => monthly,
    };
  }
}
