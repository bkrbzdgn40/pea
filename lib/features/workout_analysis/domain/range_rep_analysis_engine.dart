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

  int get repCount;

  double get lastRepRom;

  String get phaseLabel;
}
