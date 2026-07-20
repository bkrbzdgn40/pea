import '../domain/models/range_rep_technique_assessment.dart';
import 'exercise_metrics.dart';
import 'range_rep_coordinator_base.dart' as base;
import 'range_rep_exercise_analysis_extension.dart';

class NoOpRangeRepExerciseAnalysisExtension
    implements RangeRepExerciseAnalysisExtension {
  @override
  List<RangeRepTechniqueObservation> get techniqueObservations =>
      const <RangeRepTechniqueObservation>[];

  @override
  double? diagnosticMetric(RangeRepExtensionDiagnostic key) => null;

  @override
  void processFrame({
    required ExerciseMetrics metrics,
    required base.RangeRepCoordinatorFrameResult result,
    required bool isAcceptedPoseFrame,
  }) {}

  @override
  void reset() {}
}
