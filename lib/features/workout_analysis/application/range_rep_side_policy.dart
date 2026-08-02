import 'exercise_metrics.dart';

enum RangeRepSideSelectionReason {
  bilateralAggregate,
  poseMissing,
  lockedActiveRepSide,
  keptPreviousSide,
  switchedToHigherCoverage,
  selectedHigherCoverage,
  selectedMovingSide,
  switchedToMovingSide,
  keptMovingSide,
  selectedPreferredQuality,
  selectedHigherMeasurementConfidence,
  switchedToHigherMeasurementConfidence,
  selectedLeftTie,
  keptPreviousSideWithoutCoverage,
  noAvailableSide,
}

class RangeRepSideSelection {
  const RangeRepSideSelection({
    required this.selectedSide,
    required this.leftMetrics,
    required this.rightMetrics,
    required this.reason,
  });

  final RangeRepSide? selectedSide;
  final RangeRepSideMetrics leftMetrics;
  final RangeRepSideMetrics rightMetrics;
  final RangeRepSideSelectionReason reason;

  RangeRepSideMetrics? get selectedMetrics {
    switch (selectedSide) {
      case RangeRepSide.left:
        return leftMetrics;
      case RangeRepSide.right:
        return rightMetrics;
      case null:
        return null;
    }
  }

  String get debugLabel {
    switch (reason) {
      case RangeRepSideSelectionReason.bilateralAggregate:
        return 'bilateral aggregate';
      case RangeRepSideSelectionReason.poseMissing:
        return 'pose missing';
      case RangeRepSideSelectionReason.lockedActiveRepSide:
        return 'locked active rep side';
      case RangeRepSideSelectionReason.keptPreviousSide:
        return 'kept previous side';
      case RangeRepSideSelectionReason.switchedToHigherCoverage:
        return 'switched to higher coverage';
      case RangeRepSideSelectionReason.selectedHigherCoverage:
        return 'selected higher coverage';
      case RangeRepSideSelectionReason.selectedMovingSide:
        return 'selected moving side';
      case RangeRepSideSelectionReason.switchedToMovingSide:
        return 'switched to moving side';
      case RangeRepSideSelectionReason.keptMovingSide:
        return 'kept moving side';
      case RangeRepSideSelectionReason.selectedPreferredQuality:
        return 'selected preferred quality';
      case RangeRepSideSelectionReason.selectedHigherMeasurementConfidence:
        return 'selected higher measurement confidence';
      case RangeRepSideSelectionReason.switchedToHigherMeasurementConfidence:
        return 'switched to higher measurement confidence';
      case RangeRepSideSelectionReason.selectedLeftTie:
        return 'selected left tie';
      case RangeRepSideSelectionReason.keptPreviousSideWithoutCoverage:
        return 'kept previous side without coverage';
      case RangeRepSideSelectionReason.noAvailableSide:
        return 'no available side';
    }
  }
}

class RangeRepSidePolicy {
  const RangeRepSidePolicy({this.confidencePreferenceMargin = 0.05})
    : assert(confidencePreferenceMargin >= 0.0),
      assert(confidencePreferenceMargin <= 1.0);

  final double confidencePreferenceMargin;

  RangeRepSideSelection select({
    required ExerciseMetrics metrics,
    RangeRepSide? previousSide,
    RangeRepSide? preferredSide,
    RangeRepSide? movementPreferredSide,
    bool lockPreviousSide = false,
  }) {
    final leftMetrics = metrics.leftRangeRepMetrics;
    final rightMetrics = metrics.rightRangeRepMetrics;

    if (!metrics.hasPose) {
      return RangeRepSideSelection(
        selectedSide: previousSide,
        leftMetrics: leftMetrics,
        rightMetrics: rightMetrics,
        reason: RangeRepSideSelectionReason.poseMissing,
      );
    }

    if (previousSide != null && lockPreviousSide) {
      return RangeRepSideSelection(
        selectedSide: previousSide,
        leftMetrics: leftMetrics,
        rightMetrics: rightMetrics,
        reason: RangeRepSideSelectionReason.lockedActiveRepSide,
      );
    }

    if (movementPreferredSide != null) {
      return RangeRepSideSelection(
        selectedSide: movementPreferredSide,
        leftMetrics: leftMetrics,
        rightMetrics: rightMetrics,
        reason: previousSide == null
            ? RangeRepSideSelectionReason.selectedMovingSide
            : previousSide == movementPreferredSide
            ? RangeRepSideSelectionReason.keptMovingSide
            : RangeRepSideSelectionReason.switchedToMovingSide,
      );
    }

    if (previousSide != null) {
      final previousMetrics = previousSide == RangeRepSide.left
          ? leftMetrics
          : rightMetrics;
      final alternateMetrics = previousSide == RangeRepSide.left
          ? rightMetrics
          : leftMetrics;

      if (alternateMetrics.coverageScore > previousMetrics.coverageScore) {
        return RangeRepSideSelection(
          selectedSide: alternateMetrics.side,
          leftMetrics: leftMetrics,
          rightMetrics: rightMetrics,
          reason: RangeRepSideSelectionReason.switchedToHigherCoverage,
        );
      }

      if (alternateMetrics.coverageScore == previousMetrics.coverageScore &&
          alternateMetrics.coverageScore > 0 &&
          _hasMeaningfulConfidenceAdvantage(
            alternateMetrics,
            previousMetrics,
          )) {
        return RangeRepSideSelection(
          selectedSide: alternateMetrics.side,
          leftMetrics: leftMetrics,
          rightMetrics: rightMetrics,
          reason:
              RangeRepSideSelectionReason.switchedToHigherMeasurementConfidence,
        );
      }

      if (preferredSide != null && preferredSide != previousSide) {
        final preferredMetrics = preferredSide == RangeRepSide.left
            ? leftMetrics
            : rightMetrics;
        if (preferredMetrics.coverageScore > 0 &&
            preferredMetrics.coverageScore == previousMetrics.coverageScore) {
          return RangeRepSideSelection(
            selectedSide: preferredSide,
            leftMetrics: leftMetrics,
            rightMetrics: rightMetrics,
            reason: RangeRepSideSelectionReason.selectedPreferredQuality,
          );
        }
      }

      if (previousMetrics.coverageScore > 0) {
        return RangeRepSideSelection(
          selectedSide: previousSide,
          leftMetrics: leftMetrics,
          rightMetrics: rightMetrics,
          reason: RangeRepSideSelectionReason.keptPreviousSide,
        );
      }

      if (alternateMetrics.coverageScore > 0) {
        return RangeRepSideSelection(
          selectedSide: alternateMetrics.side,
          leftMetrics: leftMetrics,
          rightMetrics: rightMetrics,
          reason: RangeRepSideSelectionReason.selectedHigherCoverage,
        );
      }

      return RangeRepSideSelection(
        selectedSide: previousSide,
        leftMetrics: leftMetrics,
        rightMetrics: rightMetrics,
        reason: RangeRepSideSelectionReason.keptPreviousSideWithoutCoverage,
      );
    }

    if (leftMetrics.coverageScore == 0 && rightMetrics.coverageScore == 0) {
      return RangeRepSideSelection(
        selectedSide: null,
        leftMetrics: leftMetrics,
        rightMetrics: rightMetrics,
        reason: RangeRepSideSelectionReason.noAvailableSide,
      );
    }

    if (rightMetrics.coverageScore > leftMetrics.coverageScore) {
      return RangeRepSideSelection(
        selectedSide: RangeRepSide.right,
        leftMetrics: leftMetrics,
        rightMetrics: rightMetrics,
        reason: RangeRepSideSelectionReason.selectedHigherCoverage,
      );
    }

    if (leftMetrics.coverageScore > rightMetrics.coverageScore) {
      return RangeRepSideSelection(
        selectedSide: RangeRepSide.left,
        leftMetrics: leftMetrics,
        rightMetrics: rightMetrics,
        reason: RangeRepSideSelectionReason.selectedHigherCoverage,
      );
    }

    if (_hasMeaningfulConfidenceAdvantage(rightMetrics, leftMetrics)) {
      return RangeRepSideSelection(
        selectedSide: RangeRepSide.right,
        leftMetrics: leftMetrics,
        rightMetrics: rightMetrics,
        reason: RangeRepSideSelectionReason.selectedHigherMeasurementConfidence,
      );
    }
    if (_hasMeaningfulConfidenceAdvantage(leftMetrics, rightMetrics)) {
      return RangeRepSideSelection(
        selectedSide: RangeRepSide.left,
        leftMetrics: leftMetrics,
        rightMetrics: rightMetrics,
        reason: RangeRepSideSelectionReason.selectedHigherMeasurementConfidence,
      );
    }

    if (preferredSide != null) {
      final preferredMetrics = preferredSide == RangeRepSide.left
          ? leftMetrics
          : rightMetrics;
      if (preferredMetrics.coverageScore > 0) {
        return RangeRepSideSelection(
          selectedSide: preferredSide,
          leftMetrics: leftMetrics,
          rightMetrics: rightMetrics,
          reason: RangeRepSideSelectionReason.selectedPreferredQuality,
        );
      }
    }

    return RangeRepSideSelection(
      selectedSide: RangeRepSide.left,
      leftMetrics: leftMetrics,
      rightMetrics: rightMetrics,
      reason: RangeRepSideSelectionReason.selectedLeftTie,
    );
  }

  bool _hasMeaningfulConfidenceAdvantage(
    RangeRepSideMetrics candidate,
    RangeRepSideMetrics reference,
  ) {
    final candidateConfidence = candidate.measurementConfidence?.combined;
    final referenceConfidence = reference.measurementConfidence?.combined;
    if (candidateConfidence == null) {
      return false;
    }
    if (referenceConfidence == null) {
      return true;
    }
    return candidateConfidence - referenceConfidence >=
        confidencePreferenceMargin;
  }
}
