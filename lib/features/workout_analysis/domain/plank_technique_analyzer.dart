import 'models/hold_contract.dart';
import 'models/hold_signal_validity.dart';
import 'models/hold_technique_assessment.dart';

/// Converts plank-specific physical measurements into technique observations.
///
/// Pose acceptance, hold validity, hold-break, and feedback remain owned by
/// their existing layers. Legacy angular gate validity is retained only as
/// compatibility evidence. It does not determine technique severity, so the
/// old alignment/support/extension gates are not silently rebranded as three
/// equal binary technique gates. No new biomechanical threshold is invented.
class PlankTechniqueAnalyzer {
  const PlankTechniqueAnalyzer();

  HoldTechniqueAssessment assess({
    required double? hipDeviation,
    required double? shoulderElbowOffset,
    required double? kneeExtensionAngle,
    HoldSignalValidity legacySignalValidity = const HoldSignalValidity.empty(),
  }) {
    final observations = <HoldTechniqueObservation>[];

    if (hipDeviation != null) {
      final legacyGatePassed = legacySignalValidity.validityFor(
        HoldSignal.alignment,
      );
      observations.add(
        HoldTechniqueObservation(
          type: HoldTechniqueObservationType.plankHipDeviation,
          code: 'plank_hip_deviation_observed',
          severity: HoldTechniqueSeverity.info,
          measuredValue: hipDeviation,
          legacyGatePassed: legacyGatePassed,
        ),
      );
    }

    if (shoulderElbowOffset != null) {
      final legacyGatePassed = legacySignalValidity.validityFor(
        HoldSignal.support,
      );
      observations.add(
        HoldTechniqueObservation(
          type: HoldTechniqueObservationType.plankShoulderElbowOffset,
          code: 'plank_shoulder_elbow_offset_observed',
          severity: HoldTechniqueSeverity.info,
          measuredValue: shoulderElbowOffset,
          legacyGatePassed: legacyGatePassed,
        ),
      );
    }

    if (kneeExtensionAngle != null) {
      final legacyGatePassed = legacySignalValidity.validityFor(
        HoldSignal.extension,
      );
      observations.add(
        HoldTechniqueObservation(
          type: HoldTechniqueObservationType.plankKneeExtension,
          code: 'plank_knee_extension_observed',
          severity: HoldTechniqueSeverity.info,
          measuredValue: kneeExtensionAngle,
          legacyGatePassed: legacyGatePassed,
        ),
      );
    }

    return HoldTechniqueAssessment(observations: observations);
  }
}
