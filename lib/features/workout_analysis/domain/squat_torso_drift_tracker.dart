import 'models/range_rep_technique_assessment.dart';
import 'squat_torso_drift_observation_builder.dart';

/// Tracks representative squat torso inclinations by rep phase and emits
/// threshold-free observations when a later phase can be compared with the
/// immediately preceding phase.
///
/// Each phase keeps its first finite physical measurement. This prevents frames
/// spent stabilizing the next transition from overwriting the previous phase's
/// representative value. Missing measurements do not fabricate zeroes and
/// therefore do not produce observations. [reset] must be called when the
/// active rep context ends.
class SquatTorsoDriftTracker {
  SquatTorsoDriftTracker({
    SquatTorsoDriftObservationBuilder observationBuilder =
        const SquatTorsoDriftObservationBuilder(),
  }) : _observationBuilder = observationBuilder;

  final SquatTorsoDriftObservationBuilder _observationBuilder;
  final Map<RangeRepTechniquePhase, double> _phaseInclinations =
      <RangeRepTechniquePhase, double>{};

  void record({
    required RangeRepTechniquePhase phase,
    required double? inclinationDegrees,
  }) {
    if (inclinationDegrees == null || !inclinationDegrees.isFinite) {
      return;
    }
    _phaseInclinations.putIfAbsent(phase, () => inclinationDegrees);
  }

  RangeRepTechniqueObservation? observeTransition({
    required RangeRepTechniquePhase referencePhase,
    required RangeRepTechniquePhase measuredPhase,
  }) {
    final referenceValue = _phaseInclinations[referencePhase];
    final measuredValue = _phaseInclinations[measuredPhase];
    if (referenceValue == null || measuredValue == null) {
      return null;
    }

    return _observationBuilder.build(
      referencePhase: referencePhase,
      referenceInclinationDegrees: referenceValue,
      measuredPhase: measuredPhase,
      measuredInclinationDegrees: measuredValue,
    );
  }

  void reset() => _phaseInclinations.clear();
}
