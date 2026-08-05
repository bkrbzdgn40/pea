import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/session_measurement_evidence.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/models/preparation_start_gate_state.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/pending_preparation_outcome_provider.dart';

void main() {
  test(
    'maps preparation approval sources without inventing unknown evidence',
    () {
      expect(
        preparationOutcomeFromApprovalSource(
          PreparationStartApprovalSource.readiness,
        ),
        PreparationOutcome.passed,
      );
      expect(
        preparationOutcomeFromApprovalSource(
          PreparationStartApprovalSource.manualOverride,
        ),
        PreparationOutcome.overridden,
      );
      expect(
        preparationOutcomeFromApprovalSource(null),
        PreparationOutcome.legacyUnknown,
      );
    },
  );
}
