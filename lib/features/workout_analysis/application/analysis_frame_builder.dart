import '../../../../core/utils/moving_average.dart';
import '../domain/models/analysis_frame.dart';
import 'exercise_metrics.dart';

/// Assembles the engine-facing analysis frame with the existing smoothing order.
class WorkoutAnalysisFrameBuilder {
  const WorkoutAnalysisFrameBuilder();

  AnalysisFrame build({
    required ExerciseMetrics metrics,
    required MovingAverageFilter primaryMetricFilter,
    required MovingAverageFilter formMetricFilter,
    required MovingAverageFilter bodyLineFilter,
    required MovingAverageFilter armSupportFilter,
    required MovingAverageFilter legFilter,
    RangeRepAnalysisMetrics? rangeRepMetrics,
  }) {
    final primaryMetric = rangeRepMetrics?.primaryAngle ?? metrics.primaryAngle;
    final formMetric = rangeRepMetrics?.formMetric ?? metrics.formMetric;

    return AnalysisFrame(
      primaryMetric: primaryMetricFilter.process(primaryMetric),
      formMetric: formMetricFilter.process(formMetric),
      bodyLineAngle: _smoothOptional(metrics.bodyLineAngle, bodyLineFilter),
      armSupportAngle: _smoothOptional(
        metrics.armSupportAngle,
        armSupportFilter,
      ),
      legExtensionAngle: _smoothOptional(metrics.legExtensionAngle, legFilter),
    );
  }

  double? _smoothOptional(double? value, MovingAverageFilter filter) {
    if (value == null) {
      return null;
    }

    return filter.process(value);
  }
}
