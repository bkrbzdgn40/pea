import 'analysis_engine.dart';
import 'models/range_rep_engine_frame_result.dart';
import 'range_rep_diagnostics.dart';

abstract interface class RangeRepAnalysisEngine
    implements
        AnalysisEngine,
        RangeRepDetectionDiagnostics,
        RangeRepResyncControl,
        RangeRepVisibilityGapControl {
  RangeRepEngineFrameResult updateDetectionFrame({
    required double primaryMetric,
  });

  /// Controls whether the current toward-peak phase may confirm PEAK.
  ///
  /// Exercise-specific coordinators can temporarily close this gate when a
  /// second, independent geometry signal says the apparent primary metric is
  /// not yet deep enough. The gate defaults to open for all exercises.
  void setPeakEntryAllowed(bool allowed);

  int get repCount;

  double get lastRepRom;

  String get phaseLabel;
}
