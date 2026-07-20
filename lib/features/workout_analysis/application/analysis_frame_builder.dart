import '../../../core/utils/moving_average.dart';
import '../domain/models/analysis_frame.dart';
import '../domain/models/hold_contract.dart';
import '../domain/models/hold_signal_values.dart';
import 'exercise_metrics.dart';

/// Assembles the engine-facing analysis frame with the existing smoothing order.
class WorkoutAnalysisFrameBuilder {
  const WorkoutAnalysisFrameBuilder();

  AnalysisFrame build({
    required ExerciseMetrics metrics,
    required MovingAverageFilter primaryMetricFilter,
    required MovingAverageFilter formMetricFilter,
    Map<HoldSignal, MovingAverageFilter>? holdSignalFilters,
    RangeRepAnalysisMetrics? rangeRepMetrics,
  }) {
    final primaryMetric = rangeRepMetrics?.primaryAngle ?? metrics.primaryAngle;
    final formMetric = rangeRepMetrics?.formMetric ?? metrics.formMetric;

    return AnalysisFrame(
      primaryMetric: primaryMetricFilter.process(primaryMetric),
      formMetric: formMetricFilter.process(formMetric),
      holdSignalValues: _smoothHoldSignals(
        metrics.holdSignalValues,
        holdSignalFilters,
      ),
    );
  }

  HoldSignalValues _smoothHoldSignals(
    HoldSignalValues values,
    Map<HoldSignal, MovingAverageFilter>? holdSignalFilters,
  ) {
    if (holdSignalFilters == null) {
      return values;
    }

    final smoothedValues = <HoldSignal, double>{};
    for (final signal in values.signals) {
      final value = values.valueFor(signal);
      final filter = holdSignalFilters[signal];
      if (value == null || filter == null) {
        continue;
      }
      smoothedValues[signal] = filter.process(value);
    }

    return HoldSignalValues(values: smoothedValues);
  }
}
