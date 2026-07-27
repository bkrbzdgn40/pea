import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/exercise_metrics.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/range_rep_movement_side_selector.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/range_rep_contract.dart';

void main() {
  group('RangeRepMovementSideSelector', () {
    test('keeps side unresolved while both legs remain near neutral', () {
      final selector = RangeRepMovementSideSelector();

      final selected = selector.selectPreferredSide(
        leftMetrics: _metrics(RangeRepSide.left, 170),
        rightMetrics: _metrics(RangeRepSide.right, 169),
        neutralThreshold: 170,
        direction: RangeRepPrimaryMetricDirection.decreasingToPeak,
        enabled: true,
      );

      expect(selected, isNull);
      expect(selector.confirmedSide, isNull);
    });

    test('confirms the right leg after two clear movement frames', () {
      final selector = RangeRepMovementSideSelector();

      final first = selector.selectPreferredSide(
        leftMetrics: _metrics(RangeRepSide.left, 170),
        rightMetrics: _metrics(RangeRepSide.right, 150),
        neutralThreshold: 170,
        direction: RangeRepPrimaryMetricDirection.decreasingToPeak,
        enabled: true,
      );
      final second = selector.selectPreferredSide(
        leftMetrics: _metrics(RangeRepSide.left, 169),
        rightMetrics: _metrics(RangeRepSide.right, 148),
        neutralThreshold: 170,
        direction: RangeRepPrimaryMetricDirection.decreasingToPeak,
        enabled: true,
      );

      expect(first, isNull);
      expect(second, RangeRepSide.right);
      expect(selector.confirmedSide, RangeRepSide.right);
    });

    test('can confirm the only visible moving leg', () {
      final selector = RangeRepMovementSideSelector();
      const unavailableLeft = RangeRepSideMetrics.unavailable(
        RangeRepSide.left,
      );

      selector.selectPreferredSide(
        leftMetrics: unavailableLeft,
        rightMetrics: _metrics(RangeRepSide.right, 150),
        neutralThreshold: 170,
        direction: RangeRepPrimaryMetricDirection.decreasingToPeak,
        enabled: true,
      );
      final selected = selector.selectPreferredSide(
        leftMetrics: unavailableLeft,
        rightMetrics: _metrics(RangeRepSide.right, 148),
        neutralThreshold: 170,
        direction: RangeRepPrimaryMetricDirection.decreasingToPeak,
        enabled: true,
      );

      expect(selected, RangeRepSide.right);
    });

    test('ignores a one-frame excursion caused by landmark jitter', () {
      final selector = RangeRepMovementSideSelector();

      selector.selectPreferredSide(
        leftMetrics: _metrics(RangeRepSide.left, 170),
        rightMetrics: _metrics(RangeRepSide.right, 150),
        neutralThreshold: 170,
        direction: RangeRepPrimaryMetricDirection.decreasingToPeak,
        enabled: true,
      );
      final resolved = selector.selectPreferredSide(
        leftMetrics: _metrics(RangeRepSide.left, 170),
        rightMetrics: _metrics(RangeRepSide.right, 169),
        neutralThreshold: 170,
        direction: RangeRepPrimaryMetricDirection.decreasingToPeak,
        enabled: true,
      );

      expect(resolved, isNull);
      expect(selector.confirmedSide, isNull);
    });

    test('keeps the first moving leg locked between repetitions', () {
      final selector = RangeRepMovementSideSelector(confirmationFrames: 1);
      selector.selectPreferredSide(
        leftMetrics: _metrics(RangeRepSide.left, 170),
        rightMetrics: _metrics(RangeRepSide.right, 145),
        neutralThreshold: 170,
        direction: RangeRepPrimaryMetricDirection.decreasingToPeak,
        enabled: true,
      );

      final selected = selector.selectPreferredSide(
        leftMetrics: _metrics(RangeRepSide.left, 140),
        rightMetrics: _metrics(RangeRepSide.right, 170),
        neutralThreshold: 170,
        direction: RangeRepPrimaryMetricDirection.decreasingToPeak,
        enabled: true,
      );

      expect(selected, RangeRepSide.right);
      expect(selector.confirmedSide, RangeRepSide.right);
    });

    test('keeps the confirmed side through temporary primary loss', () {
      final selector = RangeRepMovementSideSelector(confirmationFrames: 1);
      selector.selectPreferredSide(
        leftMetrics: _metrics(RangeRepSide.left, 170),
        rightMetrics: _metrics(RangeRepSide.right, 145),
        neutralThreshold: 170,
        direction: RangeRepPrimaryMetricDirection.decreasingToPeak,
        enabled: true,
      );

      final selected = selector.selectPreferredSide(
        leftMetrics: _metrics(RangeRepSide.left, 170),
        rightMetrics: RangeRepSideMetrics(
          side: RangeRepSide.right,
          primaryAngle: 180,
          formMetric: 170,
          hasPrimaryAngle: false,
          hasFormMetric: true,
          sideConfidence: 1,
        ),
        neutralThreshold: 170,
        direction: RangeRepPrimaryMetricDirection.decreasingToPeak,
        enabled: true,
      );

      expect(selected, RangeRepSide.right);
      expect(selector.confirmedSide, RangeRepSide.right);
    });
  });
}

RangeRepSideMetrics _metrics(RangeRepSide side, double angle) {
  return RangeRepSideMetrics(
    side: side,
    primaryAngle: angle,
    formMetric: 170,
    hasPrimaryAngle: true,
    hasFormMetric: true,
    sideConfidence: 1,
  );
}
