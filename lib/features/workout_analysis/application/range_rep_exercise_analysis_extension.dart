import '../domain/models/range_rep_technique_assessment.dart';
import 'exercise_metrics.dart';
import 'range_rep_coordinator_base.dart' as base;

/// Stable diagnostic identifiers exposed by exercise-specific range-rep
/// extensions.
enum RangeRepExtensionDiagnostic {
  pushUpHipDeviation,
  squatHipDepth,
  bicepsRomDelta,
}

/// Exercise-owned extension point for diagnostics and biomechanics that do not
/// belong in the generic range-rep detection/coordinator flow.
///
/// Adding a new exercise-specific extension should not require adding another
/// exercise branch to the production range-rep coordinator.
abstract interface class RangeRepPeakEntryGate {
  bool allowsPeakEntry(ExerciseMetrics metrics);
}

abstract interface class RangeRepExerciseAnalysisExtension {
  List<RangeRepTechniqueObservation> get techniqueObservations;

  double? diagnosticMetric(RangeRepExtensionDiagnostic key);

  void processFrame({
    required ExerciseMetrics metrics,
    required base.RangeRepCoordinatorFrameResult result,
    required bool isAcceptedPoseFrame,
  });

  void reset();
}
