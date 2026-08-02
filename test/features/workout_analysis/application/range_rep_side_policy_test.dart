import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_metrics.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/range_rep_side_policy.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/measurement_confidence_policy.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/measurement_confidence_breakdown.dart';

void main() {
  group('RangeRepSidePolicy', () {
    const policy = RangeRepSidePolicy();
    test('keeps the previous side when it still has usable coverage', () {
      final selection = policy.select(
        metrics: _metrics(
          left: RangeRepSideMetrics(
            side: RangeRepSide.left,
            primaryAngle: 110,
            formMetric: 70,
            hasPrimaryAngle: true,
            hasFormMetric: true,
          ),
          right: RangeRepSideMetrics(
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
          left: RangeRepSideMetrics(
            side: RangeRepSide.left,
            primaryAngle: 110,
            formMetric: 90,
            hasPrimaryAngle: true,
            hasFormMetric: false,
          ),
          right: RangeRepSideMetrics(
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
          left: RangeRepSideMetrics(
            side: RangeRepSide.left,
            primaryAngle: 180,
            formMetric: 90,
            hasPrimaryAngle: false,
            hasFormMetric: false,
          ),
          right: RangeRepSideMetrics(
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

    test(
      'selects the side with higher measurement confidence on tied coverage',
      () {
        final selection = policy.select(
          metrics: _metrics(
            left: RangeRepSideMetrics(
              side: RangeRepSide.left,
              primaryAngle: 92,
              formMetric: 120,
              hasPrimaryAngle: true,
              hasFormMetric: true,
              measurementConfidence: _confidence(0.62),
            ),
            right: RangeRepSideMetrics(
              side: RangeRepSide.right,
              primaryAngle: 90,
              formMetric: 175,
              hasPrimaryAngle: true,
              hasFormMetric: true,
              measurementConfidence: _confidence(0.94),
            ),
          ),
        );

        expect(selection.selectedSide, RangeRepSide.right);
        expect(
          selection.reason,
          RangeRepSideSelectionReason.selectedHigherMeasurementConfidence,
        );
      },
    );
    test(
      'switches from the previous side only for a meaningful confidence win',
      () {
        final selection = policy.select(
          metrics: _metrics(
            left: RangeRepSideMetrics(
              side: RangeRepSide.left,
              primaryAngle: 92,
              formMetric: 120,
              hasPrimaryAngle: true,
              hasFormMetric: true,
              measurementConfidence: _confidence(0.60),
            ),
            right: RangeRepSideMetrics(
              side: RangeRepSide.right,
              primaryAngle: 90,
              formMetric: 175,
              hasPrimaryAngle: true,
              hasFormMetric: true,
              measurementConfidence: _confidence(0.95),
            ),
          ),
          previousSide: RangeRepSide.left,
        );

        expect(selection.selectedSide, RangeRepSide.right);
        expect(
          selection.reason,
          RangeRepSideSelectionReason.switchedToHigherMeasurementConfidence,
        );
      },
    );
    test('uses the pose-quality preferred side when coverage is tied', () {
      final selection = policy.select(
        metrics: _metrics(
          left: RangeRepSideMetrics(
            side: RangeRepSide.left,
            primaryAngle: 92,
            formMetric: 120,
            hasPrimaryAngle: true,
            hasFormMetric: true,
          ),
          right: RangeRepSideMetrics(
            side: RangeRepSide.right,
            primaryAngle: 90,
            formMetric: 175,
            hasPrimaryAngle: true,
            hasFormMetric: true,
          ),
        ),
        preferredSide: RangeRepSide.right,
      );

      expect(selection.selectedSide, RangeRepSide.right);
      expect(
        selection.reason,
        RangeRepSideSelectionReason.selectedPreferredQuality,
      );
    });
    test(
      'lets an equally covered preferred side challenge the previous side',
      () {
        final selection = policy.select(
          metrics: _metrics(
            left: RangeRepSideMetrics(
              side: RangeRepSide.left,
              primaryAngle: 92,
              formMetric: 120,
              hasPrimaryAngle: true,
              hasFormMetric: true,
            ),
            right: RangeRepSideMetrics(
              side: RangeRepSide.right,
              primaryAngle: 90,
              formMetric: 175,
              hasPrimaryAngle: true,
              hasFormMetric: true,
            ),
          ),
          previousSide: RangeRepSide.left,
          preferredSide: RangeRepSide.right,
        );

        expect(selection.selectedSide, RangeRepSide.right);
        expect(
          selection.reason,
          RangeRepSideSelectionReason.selectedPreferredQuality,
        );
      },
    );
    test('does not let preferred quality override higher signal coverage', () {
      final selection = policy.select(
        metrics: _metrics(
          left: RangeRepSideMetrics(
            side: RangeRepSide.left,
            primaryAngle: 92,
            formMetric: 175,
            hasPrimaryAngle: true,
            hasFormMetric: true,
          ),
          right: RangeRepSideMetrics(
            side: RangeRepSide.right,
            primaryAngle: 90,
            formMetric: 90,
            hasPrimaryAngle: true,
            hasFormMetric: false,
          ),
        ),
        preferredSide: RangeRepSide.right,
      );

      expect(selection.selectedSide, RangeRepSide.left);
      expect(
        selection.reason,
        RangeRepSideSelectionReason.selectedHigherCoverage,
      );
    });
    test('movement preference overrides an equally covered previous side', () {
      final selection = policy.select(
        metrics: _metrics(
          left: RangeRepSideMetrics(
            side: RangeRepSide.left,
            primaryAngle: 170,
            formMetric: 70,
            hasPrimaryAngle: true,
            hasFormMetric: true,
          ),
          right: RangeRepSideMetrics(
            side: RangeRepSide.right,
            primaryAngle: 120,
            formMetric: 70,
            hasPrimaryAngle: true,
            hasFormMetric: true,
          ),
        ),
        previousSide: RangeRepSide.left,
        movementPreferredSide: RangeRepSide.right,
      );

      expect(selection.selectedSide, RangeRepSide.right);
      expect(
        selection.reason,
        RangeRepSideSelectionReason.switchedToMovingSide,
      );
    });
    test('keeps a movement-locked side through temporary signal loss', () {
      final selection = policy.select(
        metrics: _metrics(
          left: RangeRepSideMetrics(
            side: RangeRepSide.left,
            primaryAngle: 170,
            formMetric: 70,
            hasPrimaryAngle: true,
            hasFormMetric: true,
          ),
          right: const RangeRepSideMetrics.unavailable(RangeRepSide.right),
        ),
        previousSide: RangeRepSide.right,
        movementPreferredSide: RangeRepSide.right,
      );

      expect(selection.selectedSide, RangeRepSide.right);
      expect(selection.reason, RangeRepSideSelectionReason.keptMovingSide);
    });
    test('returns noAvailableSide when both sides have zero coverage', () {
      final selection = policy.select(
        metrics: _metrics(
          left: RangeRepSideMetrics(
            side: RangeRepSide.left,
            primaryAngle: 180,
            formMetric: 90,
            hasPrimaryAngle: false,
            hasFormMetric: false,
          ),
          right: RangeRepSideMetrics(
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
            left: RangeRepSideMetrics(
              side: RangeRepSide.left,
              primaryAngle: 180,
              formMetric: 90,
              hasPrimaryAngle: false,
              hasFormMetric: false,
            ),
            right: RangeRepSideMetrics(
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

MeasurementConfidenceBreakdown _confidence(double value) {
  return const MeasurementConfidencePolicy().evaluate(
    landmarkLikelihood: value,
    signalAvailability: 1.0,
    geometryPlausibility: 1.0,
    temporalContinuity: 1.0,
  );
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
