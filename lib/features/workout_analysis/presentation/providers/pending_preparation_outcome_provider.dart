import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/session_measurement_evidence.dart';
import '../models/preparation_start_gate_state.dart';

/// Preparation evidence captured immediately before opening live analysis.
final pendingPreparationOutcomeProvider = StateProvider<PreparationOutcome>(
  (ref) => PreparationOutcome.legacyUnknown,
);

PreparationOutcome preparationOutcomeFromApprovalSource(
  PreparationStartApprovalSource? source,
) {
  return switch (source) {
    PreparationStartApprovalSource.readiness => PreparationOutcome.passed,
    PreparationStartApprovalSource.manualOverride =>
      PreparationOutcome.overridden,
    null => PreparationOutcome.legacyUnknown,
  };
}
