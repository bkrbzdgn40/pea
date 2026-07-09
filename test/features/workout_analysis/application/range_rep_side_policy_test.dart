import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_metrics.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/range_rep_side_policy.dart';

void main() {
  group('RangeRepSidePolicy', () {
    const policy = RangeRepSidePolicy();

    test('keeps the previous side when it still has usable coverage', () {
      final selection = policy.select(
        metrics: _metrics(
          left: const RangeRepSideMetrics(
            side: RangeRepSide.left,
            primaryAngle: 110,
            formMetric: 70,
            hasPrimaryAngle: true,
            hasFormMetric: true,
          ),
          right: const RangeRepSideMetrics(
            side: RangeRepSide.right,
            primaryAngle: 112,
            formMetric: 90,
            hasPrimaryAngle: true,
            hasFormMetric: false,
          ),
        ),
        previousSide: RangeRepSide.left,
      );

      expect(selection.selectedSide, RangeRepSide.left);
      expect(selection.reason, RangeRepSideSelectionReason.keptPreviousSide);
    });

    test('switches only when the alternate side has higher coverage', () {
      final selection = policy.select(
        metrics: _metrics(
          left: const RangeRepSideMetrics(
            side: RangeRepSide.left,
            primaryAngle: 110,
            formMetric: 90,
            hasPrimaryAngle: true,
            hasFormMetric: false,
          ),
          right: const RangeRepSideMetrics(
            side: RangeRepSide.right,
            primaryAngle: 95,
            formMetric: 65,
            hasPrimaryAngle: true,
            hasFormMetric: true,
          ),
        ),
        previousSide: RangeRepSide.left,
      );

      expect(selection.selectedSide, RangeRepSide.right);
      expect(
        selection.reason,
        RangeRepSideSelectionReason.switchedToHigherCoverage,
      );
    });

    test('selects the higher coverage side when no previous side exists', () {
      final selection = policy.select(
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
            primaryAngle: 95,
            formMetric: 65,
            hasPrimaryAngle: true,
            hasFormMetric: true,
          ),
        ),
      );

      expect(selection.selectedSide, RangeRepSide.right);
      expect(
        selection.reason,
        RangeRepSideSelectionReason.selectedHigherCoverage,
      );
    });

    test('returns noAvailableSide when both sides have zero coverage', () {
      final selection = policy.select(
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
            primaryAngle: 180,
            formMetric: 90,
            hasPrimaryAngle: false,
            hasFormMetric: false,
          ),
        ),
      );

      expect(selection.selectedSide, isNull);
      expect(selection.selectedMetrics, isNull);
      expect(selection.reason, RangeRepSideSelectionReason.noAvailableSide);
    });

    test(
      'locks the active rep to the previous side to avoid mixed-side input',
      () {
        final selection = policy.select(
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
              primaryAngle: 90,
              formMetric: 60,
              hasPrimaryAngle: true,
              hasFormMetric: true,
            ),
          ),
          previousSide: RangeRepSide.left,
          lockPreviousSide: true,
        );

        expect(selection.selectedSide, RangeRepSide.left);
        expect(selection.selectedMetrics, same(selection.leftMetrics));
        expect(
          selection.reason,
          RangeRepSideSelectionReason.lockedActiveRepSide,
        );
      },
    );
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
