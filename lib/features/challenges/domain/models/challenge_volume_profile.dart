import 'challenge_metric.dart';

/// Product-owned threshold profile shared by exercises with similar volume.
enum ChallengeVolumeProfile {
  r1LowVolume('R1_LOW_VOLUME', ChallengeMetric.validRepetitions),
  r2Standard('R2_STANDARD', ChallengeMetric.validRepetitions),
  r3MediumHigh('R3_MEDIUM_HIGH', ChallengeMetric.validRepetitions),
  r4HighVolume('R4_HIGH_VOLUME', ChallengeMetric.validRepetitions),
  r5CardioVolume('R5_CARDIO_VOLUME', ChallengeMetric.validRepetitions),
  h1AdvancedShort('H1_ADVANCED_SHORT', ChallengeMetric.trustedHoldSeconds),
  h2SideHold('H2_SIDE_HOLD', ChallengeMetric.trustedHoldSeconds),
  h3StandardHold('H3_STANDARD_HOLD', ChallengeMetric.trustedHoldSeconds),
  h4EnduranceHold('H4_ENDURANCE_HOLD', ChallengeMetric.trustedHoldSeconds);

  const ChallengeVolumeProfile(this.storageValue, this.metric);

  final String storageValue;
  final ChallengeMetric metric;
}
