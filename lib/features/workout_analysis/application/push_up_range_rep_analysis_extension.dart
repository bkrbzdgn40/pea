import '../domain/models/range_rep_technique_assessment.dart';
import 'exercise_metrics.dart';
import 'push_up_hip_deviation_measurement.dart';
import 'range_rep_coordinator_base.dart' as base;
import 'range_rep_exercise_analysis_extension.dart';
import 'range_rep_extension_pose_utils.dart';

class PushUpRangeRepExerciseAnalysisExtension
    implements RangeRepExerciseAnalysisExtension {
  final PushUpHipDeviationMeasurement _hipDeviationMeasurement =
      const PushUpHipDeviationMeasurement();

  double? _currentHipDeviationMetric;

  @override
  List<RangeRepTechniqueObservation> get techniqueObservations =>
      const <RangeRepTechniqueObservation>[];

  @override
  double? diagnosticMetric(RangeRepExtensionDiagnostic key) {
    return key == RangeRepExtensionDiagnostic.pushUpHipDeviation
        ? _currentHipDeviationMetric
        : null;
  }

  @override
  void processFrame({
    required ExerciseMetrics metrics,
    required base.RangeRepCoordinatorFrameResult result,
    required bool isAcceptedPoseFrame,
  }) {
    if (!isAcceptedPoseFrame) {
      _currentHipDeviationMetric = null;
      return;
    }

    final side = rangeRepSideFromLabel(
      result.diagnosticsUpdate.selectedSideLabel,
    );
    _currentHipDeviationMetric = side == null
        ? null
        : _hipDeviationMeasurement.measure(
            poseFromLandmarks(metrics.landmarks),
            side: side,
          );
  }

  @override
  void reset() {
    _currentHipDeviationMetric = null;
  }
}
