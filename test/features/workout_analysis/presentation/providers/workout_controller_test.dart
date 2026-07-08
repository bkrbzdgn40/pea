import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/engine_kind.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_metrics.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/range_rep_side_policy.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/range_rep_diagnostics.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/workout_controller.dart';

void main() {
  group('WorkoutController side lock seam', () {
    const sidePolicy = RangeRepSidePolicy();

    test(
      'keeps the previous side locked during a pending neutral to descending transition',
      () {
        final diagnostics = RangeRepDiagnosticsSnapshot(
          hasActiveRepPhase: false,
          hasPendingTransition: true,
          pendingTransitionLabel: 'neutral -> descending',
        );
        final shouldLock = shouldLockRangeRepSideSelection(
          engineKind: EngineKind.rangeRep,
          selectedSide: RangeRepSide.left,
          diagnostics: diagnostics,
        );

        final selection = sidePolicy.select(
          metrics: _metrics(
            left: const RangeRepSideMetrics(
              side: RangeRepSide.left,
              primaryAngle: 180,
              formMetric: 90,
              hasPrimaryAngle: false,
              hasFormMetric: false,
            ),
            right: const RangeRepSideMetrics(
              side: RangeRepSide.right,
              primaryAngle: 92,
              formMetric: 62,
              hasPrimaryAngle: true,
              hasFormMetric: true,
            ),
          ),
          previousSide: RangeRepSide.left,
          lockPreviousSide: shouldLock,
        );

        expect(shouldLock, isTrue);
        expect(selection.selectedSide, RangeRepSide.left);
        expect(
          selection.reason,
          RangeRepSideSelectionReason.lockedActiveRepSide,
        );
      },
    );

    test('does not lock a neutral engine without a pending transition', () {
      final diagnostics = RangeRepDiagnosticsSnapshot(
        hasActiveRepPhase: false,
        hasPendingTransition: false,
      );
      final shouldLock = shouldLockRangeRepSideSelection(
        engineKind: EngineKind.rangeRep,
        selectedSide: RangeRepSide.left,
        diagnostics: diagnostics,
      );

      final selection = sidePolicy.select(
        metrics: _metrics(
          left: const RangeRepSideMetrics(
            side: RangeRepSide.left,
            primaryAngle: 180,
            formMetric: 90,
            hasPrimaryAngle: false,
            hasFormMetric: false,
          ),
          right: const RangeRepSideMetrics(
            side: RangeRepSide.right,
            primaryAngle: 92,
            formMetric: 62,
            hasPrimaryAngle: true,
            hasFormMetric: true,
          ),
        ),
        previousSide: RangeRepSide.left,
        lockPreviousSide: shouldLock,
      );

      expect(shouldLock, isFalse);
      expect(selection.selectedSide, RangeRepSide.right);
      expect(
        selection.reason,
        RangeRepSideSelectionReason.switchedToHigherCoverage,
      );
    });
  });
}

ExerciseMetrics _metrics({
  required RangeRepSideMetrics left,
  required RangeRepSideMetrics right,
}) {
  return ExerciseMetrics(
    primaryAngle: left.primaryAngle,
    formMetric: left.formMetric,
    hasPrimaryAngle: left.hasPrimaryAngle,
    hasFormMetric: left.hasFormMetric,
    hasPose: true,
    landmarks: const [],
    leftRangeRepMetrics: left,
    rightRangeRepMetrics: right,
  );
}
