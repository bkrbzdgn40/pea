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

/// Exercise-owned extension point for legacy peak-entry checks.
///
/// New selected-side movement evidence should use
/// [RangeRepDetectionFrameAdapter]. This interface remains for bilateral
/// extensions whose gate does not depend on coordinator side selection.
abstract interface class RangeRepPeakEntryGate {
  bool allowsPeakEntry(ExerciseMetrics metrics);
}

/// Immutable input for exercise-specific detection adaptation.
///
/// The coordinator creates this context only after pose-quality filtering and
/// side selection. The extension therefore evaluates the same side and frame
/// that will be sent to the range-rep engine.
class RangeRepDetectionFrameContext {
  const RangeRepDetectionFrameContext({
    required this.metrics,
    required this.selectedSide,
    required this.primaryMetric,
    required this.neutralThreshold,
    required this.activeThreshold,
    required this.currentPhase,
    required this.hasActiveRepContext,
    required this.now,
  });

  final ExerciseMetrics metrics;
  final RangeRepSide selectedSide;
  final double primaryMetric;
  final double neutralThreshold;
  final double activeThreshold;
  final String currentPhase;
  final bool hasActiveRepContext;
  final DateTime now;
}

/// Adapts the engine-facing primary metric using exercise-owned movement
/// identity evidence.
///
/// This is deliberately narrower than pose acceptance and validation. Pose
/// quality decides whether the frame is usable; this adapter decides whether a
/// usable scalar excursion actually represents the configured exercise.
abstract interface class RangeRepDetectionFrameAdapter {
  double adaptPrimaryMetric(RangeRepDetectionFrameContext context);
}

/// Exercise-owned extension point for diagnostics and biomechanics that do not
/// belong in the generic range-rep detection/coordinator flow.
///
/// Adding a new exercise-specific extension should not require adding another
/// exercise branch to the production range-rep coordinator.
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
