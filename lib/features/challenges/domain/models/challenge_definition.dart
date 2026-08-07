import '../../../workout_analysis/domain/models/exercise_type.dart';
import 'challenge_metric.dart';
import 'challenge_period.dart';
import 'challenge_period_thresholds.dart';
import 'challenge_volume_profile.dart';
import 'medal_thresholds.dart';

/// Immutable V1 challenge definition for one exercise.
class ChallengeDefinition {
  const ChallengeDefinition({
    required this.exerciseType,
    required this.profile,
    required this.thresholds,
    required this.catalogVersion,
  });

  final ExerciseType exerciseType;
  final ChallengeVolumeProfile profile;
  final ChallengePeriodThresholds thresholds;
  final int catalogVersion;

  String get id => '${exerciseType.id}_volume';
  ChallengeMetric get metric => profile.metric;

  MedalThresholds thresholdsFor(ChallengePeriod period) {
    return thresholds.forPeriod(period);
  }
}
