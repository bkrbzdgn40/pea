import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/engine_kind.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/range_rep_rep_outcome_tracker.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/range_rep_diagnostics.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/range_rep_validation_policy.dart';

void main() {
  test('locks the first active side while still reporting a later switch', () {
    final tracker = RangeRepRepOutcomeTracker(
      validationPolicy: const RangeRepValidationPolicy(
        config: RangeRepValidationConfig(),
      ),
    );
    const activeDiagnostics = RangeRepDiagnosticsSnapshot(
      hasActiveRepPhase: true,
    );

    tracker.trackRepContext(
      engineKind: EngineKind.rangeRep,
      diagnostics: activeDiagnostics,
      selectedSideLabel: 'left',
    );
    tracker.trackRepContext(
      engineKind: EngineKind.rangeRep,
      diagnostics: activeDiagnostics,
      selectedSideLabel: 'right',
    );

    final outcome = tracker.activateCompletedRepOutcomeIfAny(
      engineKind: EngineKind.rangeRep,
      analysisKindLabel: EngineKind.rangeRep.name,
      completedRepCoreData: const RangeRepCompletedRepCoreData(
        repIndex: 1,
        minAngle: 90,
        worstFormMetric: 0,
        descentDuration: Duration(milliseconds: 600),
        ascentDuration: Duration(milliseconds: 600),
        hadFormViolation: false,
        completedPhaseSequence: true,
        startAngle: 170,
        primaryRom: 80,
        totalRepDuration: Duration(milliseconds: 1200),
      ),
    );

    expect(outcome, isNotNull);
    expect(outcome!.summary.selectedSideLabel, 'left');
    expect(outcome.summary.switchedSideDuringRep, isTrue);
  });
}
