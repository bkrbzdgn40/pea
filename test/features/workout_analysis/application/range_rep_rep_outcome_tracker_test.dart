import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/engine_kind.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/range_rep_rep_outcome_tracker.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/range_rep_aborted_attempt_detection_data.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/range_rep_validation_result.dart';
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

  test(
    'keeps attempt indices monotonic across a shallow abort and completion',
    () {
      final tracker = RangeRepRepOutcomeTracker(
        validationPolicy: const RangeRepValidationPolicy(
          config: RangeRepValidationConfig(
            invalidateAbortToNeutralAsInsufficientRom: true,
          ),
        ),
      );
      const activeDiagnostics = RangeRepDiagnosticsSnapshot(
        hasActiveRepPhase: true,
      );

      tracker.trackRepContext(
        engineKind: EngineKind.rangeRep,
        diagnostics: activeDiagnostics,
        selectedSideLabel: 'left',
        frameConfidence: 1,
      );
      final rejected = tracker.activateShallowAbortedRepOutcomeIfAny(
        engineKind: EngineKind.rangeRep,
        analysisKindLabel: EngineKind.rangeRep.name,
        abortedAttemptData: const RangeRepAbortedAttemptDetectionData(
          minAngle: 125,
          descentDuration: Duration(milliseconds: 500),
          startAngle: 140,
          primaryRom: 15,
        ),
        worstFormMetric: 170,
        hadFormViolation: false,
      );

      expect(rejected, isNotNull);
      expect(rejected!.attemptIndex, 1);
      expect(rejected.status, RangeRepValidationStatus.invalid);
      expect(rejected.reasons, <RangeRepValidationReason>[
        RangeRepValidationReason.insufficientRom,
      ]);
      expect(tracker.rangeRepAcceptedCount, 0);
      expect(tracker.rangeRepInvalidCount, 1);

      tracker.trackRepContext(
        engineKind: EngineKind.rangeRep,
        diagnostics: activeDiagnostics,
        selectedSideLabel: 'left',
        frameConfidence: 1,
      );
      const completion = RangeRepCompletedRepCoreData(
        repIndex: 1,
        minAngle: 100,
        worstFormMetric: 170,
        descentDuration: Duration(milliseconds: 700),
        ascentDuration: Duration(milliseconds: 700),
        hadFormViolation: false,
        completedPhaseSequence: true,
        startAngle: 160,
        primaryRom: 60,
        totalRepDuration: Duration(milliseconds: 1400),
      );
      final accepted = tracker.activateCompletedRepOutcomeIfAny(
        engineKind: EngineKind.rangeRep,
        analysisKindLabel: EngineKind.rangeRep.name,
        completedRepCoreData: completion,
      );

      expect(accepted, isNotNull);
      expect(accepted!.attemptIndex, 2);
      expect(accepted.status, RangeRepValidationStatus.valid);
      expect(tracker.rangeRepAcceptedCount, 1);
      expect(tracker.lastRangeRepValidatedRepIndex, 2);

      expect(
        tracker.activateCompletedRepOutcomeIfAny(
          engineKind: EngineKind.rangeRep,
          analysisKindLabel: EngineKind.rangeRep.name,
          completedRepCoreData: completion,
        ),
        isNull,
      );
    },
  );
}
