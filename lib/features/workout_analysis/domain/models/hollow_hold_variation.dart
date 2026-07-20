enum HollowHoldVariation { tuck, bentKnee, straightLeg, straightLegOverhead }

/// Explicit setup/validation ownership for Hollow Hold variants.
///
/// No new biomechanical thresholds live here. The contract only states which
/// existing posture requirements apply to a selected variation and which
/// physical measurements are relevant for diagnostics.
class HollowHoldVariationContract {
  const HollowHoldVariationContract({
    required this.variation,
    required this.requiresStraightKnees,
    required this.requiresArmsOverhead,
    required this.usesShoulderElevation,
    required this.usesHeelElevation,
  });

  final HollowHoldVariation variation;
  final bool requiresStraightKnees;
  final bool requiresArmsOverhead;
  final bool usesShoulderElevation;
  final bool usesHeelElevation;
}

abstract final class HollowHoldVariationContracts {
  static const HollowHoldVariationContract tuck = HollowHoldVariationContract(
    variation: HollowHoldVariation.tuck,
    requiresStraightKnees: false,
    requiresArmsOverhead: false,
    usesShoulderElevation: true,
    usesHeelElevation: true,
  );

  static const HollowHoldVariationContract bentKnee =
      HollowHoldVariationContract(
        variation: HollowHoldVariation.bentKnee,
        requiresStraightKnees: false,
        requiresArmsOverhead: false,
        usesShoulderElevation: true,
        usesHeelElevation: true,
      );

  static const HollowHoldVariationContract straightLeg =
      HollowHoldVariationContract(
        variation: HollowHoldVariation.straightLeg,
        requiresStraightKnees: true,
        requiresArmsOverhead: false,
        usesShoulderElevation: true,
        usesHeelElevation: true,
      );

  static const HollowHoldVariationContract straightLegOverhead =
      HollowHoldVariationContract(
        variation: HollowHoldVariation.straightLegOverhead,
        requiresStraightKnees: true,
        requiresArmsOverhead: true,
        usesShoulderElevation: true,
        usesHeelElevation: true,
      );

  static HollowHoldVariationContract forVariation(
    HollowHoldVariation variation,
  ) {
    return switch (variation) {
      HollowHoldVariation.tuck => tuck,
      HollowHoldVariation.bentKnee => bentKnee,
      HollowHoldVariation.straightLeg => straightLeg,
      HollowHoldVariation.straightLegOverhead => straightLegOverhead,
    };
  }
}
