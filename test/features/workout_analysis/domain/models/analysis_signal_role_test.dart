import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/analysis_signal_role.dart';

void main() {
  test('AnalysisSignalRole exposes exactly the roadmap role taxonomy', () {
    expect(AnalysisSignalRole.values, <AnalysisSignalRole>[
      AnalysisSignalRole.detection,
      AnalysisSignalRole.validation,
      AnalysisSignalRole.setup,
      AnalysisSignalRole.technique,
      AnalysisSignalRole.scoring,
    ]);
  });
}
