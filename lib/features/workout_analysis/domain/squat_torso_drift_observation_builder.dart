import 'models/range_rep_technique_assessment.dart';

/// Builds threshold-free squat torso-drift observations between rep phases.
///
/// The observation records the physical image-plane torso inclinations at the
/// reference and measured phases. It deliberately uses [RangeRepTechniqueSeverity.info]
/// because R15B introduces measurement/observation semantics only; it does not
/// define a biomechanical acceptance threshold or a scoring penalty.
class SquatTorsoDriftObservationBuilder {
  const SquatTorsoDriftObservationBuilder();

  RangeRepTechniqueObservation build({
    required RangeRepTechniquePhase referencePhase,
    required double referenceInclinationDegrees,
    required RangeRepTechniquePhase measuredPhase,
    required double measuredInclinationDegrees,
  }) {
    return RangeRepTechniqueObservation(
      type: RangeRepTechniqueObservationType.torsoDrift,
      code: 'squat_torso_drift_observed',
      severity: RangeRepTechniqueSeverity.info,
      phase: measuredPhase,
      referencePhase: referencePhase,
      measuredValue: measuredInclinationDegrees,
      referenceValue: referenceInclinationDegrees,
    );
  }
}
