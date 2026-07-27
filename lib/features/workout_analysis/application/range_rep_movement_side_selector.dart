import '../domain/models/range_rep_contract.dart';
import 'exercise_metrics.dart';

/// Detects which side actually starts a unilateral movement.
///
/// Pose-quality filtering still decides which landmark sides are usable. This
/// selector compares every available side's excursion from the configured
/// neutral threshold. A candidate must win for consecutive frames so ordinary
/// landmark jitter cannot lock the wrong leg.
class RangeRepMovementSideSelector {
  RangeRepMovementSideSelector({
    this.confirmationFrames = 2,
    this.minimumExcursionDegrees = 6.0,
    this.minimumAdvantageDegrees = 4.0,
  }) : assert(confirmationFrames > 0),
       assert(minimumExcursionDegrees >= 0),
       assert(minimumAdvantageDegrees >= 0);

  final int confirmationFrames;
  final double minimumExcursionDegrees;
  final double minimumAdvantageDegrees;

  RangeRepSide? _confirmedSide;
  RangeRepSide? _pendingSide;
  int _pendingWins = 0;

  RangeRepSide? get confirmedSide => _confirmedSide;

  RangeRepSide? selectPreferredSide({
    required RangeRepSideMetrics leftMetrics,
    required RangeRepSideMetrics rightMetrics,
    required double neutralThreshold,
    required RangeRepPrimaryMetricDirection direction,
    required bool enabled,
  }) {
    if (!enabled) {
      reset();
      return null;
    }

    if (_confirmedSide != null) {
      _clearPending();
      return _confirmedSide;
    }

    final candidate = _movementCandidate(
      leftMetrics: leftMetrics,
      rightMetrics: rightMetrics,
      neutralThreshold: neutralThreshold,
      direction: direction,
    );

    if (candidate == null) {
      _clearPending();
      return _confirmedSide;
    }

    if (_pendingSide == candidate) {
      _pendingWins += 1;
    } else {
      _pendingSide = candidate;
      _pendingWins = 1;
    }

    if (_pendingWins >= confirmationFrames) {
      _confirmedSide = candidate;
      _clearPending();
    }

    return _confirmedSide;
  }

  void reset() {
    _confirmedSide = null;
    _clearPending();
  }

  RangeRepSide? _movementCandidate({
    required RangeRepSideMetrics leftMetrics,
    required RangeRepSideMetrics rightMetrics,
    required double neutralThreshold,
    required RangeRepPrimaryMetricDirection direction,
  }) {
    if (!leftMetrics.hasPrimaryAngle && !rightMetrics.hasPrimaryAngle) {
      return null;
    }

    final leftExcursion = leftMetrics.hasPrimaryAngle
        ? _towardPeakExcursion(
            leftMetrics.primaryAngle,
            neutralThreshold: neutralThreshold,
            direction: direction,
          )
        : 0.0;
    final rightExcursion = rightMetrics.hasPrimaryAngle
        ? _towardPeakExcursion(
            rightMetrics.primaryAngle,
            neutralThreshold: neutralThreshold,
            direction: direction,
          )
        : 0.0;
    final strongestExcursion = leftExcursion > rightExcursion
        ? leftExcursion
        : rightExcursion;
    final excursionAdvantage = (leftExcursion - rightExcursion).abs();

    if (strongestExcursion < minimumExcursionDegrees ||
        excursionAdvantage < minimumAdvantageDegrees) {
      return null;
    }

    return leftExcursion > rightExcursion
        ? RangeRepSide.left
        : RangeRepSide.right;
  }

  double _towardPeakExcursion(
    double primaryAngle, {
    required double neutralThreshold,
    required RangeRepPrimaryMetricDirection direction,
  }) {
    final rawExcursion = switch (direction) {
      RangeRepPrimaryMetricDirection.decreasingToPeak =>
        neutralThreshold - primaryAngle,
      RangeRepPrimaryMetricDirection.increasingToPeak =>
        primaryAngle - neutralThreshold,
    };
    return rawExcursion < 0 ? 0 : rawExcursion;
  }

  void _clearPending() {
    _pendingSide = null;
    _pendingWins = 0;
  }
}
