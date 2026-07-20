import 'analysis_engine.dart';
import 'hold_diagnostics.dart';
import 'models/hold_feedback_code.dart';

abstract interface class HoldAnalysisEngine
    implements
        AnalysisEngine,
        HoldDiagnostics,
        HoldFeedbackSource,
        HoldVisibilityGapControl {}
