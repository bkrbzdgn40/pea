import 'analysis_engine.dart';
import 'models/analysis_frame.dart';
import 'models/range_rep_feedback_code.dart';
import 'models/range_rep_technique_assessment.dart';
import 'range_rep_diagnostics.dart';

abstract interface class RangeRepAnalysisEngine
    implements
        AnalysisEngine,
        RangeRepDiagnostics,
        RangeRepValidationHook,
        RangeRepResyncControl,
        RangeRepVisibilityGapControl,
        RangeRepFeedbackSource {
  void updateWithTechniqueAssessment(
    AnalysisFrame frame, {
    required RangeRepTechniqueAssessment techniqueAssessment,
  });

  int get repCount;

  bool get isFormBad;

  double get lastRepScore;

  double get lastRepRom;

  String get feedback;

  String get phaseLabel;
}
