import 'exercise_metrics.dart';

enum RangeRepSideSelectionReason {
  bilateralAggregate,
  poseMissing,
  lockedActiveRepSide,
  keptPreviousSide,
  switchedToHigherCoverage,
  selectedHigherCoverage,
  selectedPreferredQuality,
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
      case RangeRepSideSelectionReason.selectedPreferredQuality:
        return 'selected preferred quality';
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
  const RangeRepSidePolicy();

  RangeRepSideSelection select({
    required ExerciseMetrics metrics,
    RangeRepSide? previousSide,
    RangeRepSide? preferredSide,
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

    if (previousSide != null) {
      if (lockPreviousSide) {
        return RangeRepSideSelection(
          selectedSide: previousSide,
          leftMetrics: leftMetrics,
          rightMetrics: rightMetrics,
          reason: RangeRepSideSelectionReason.lockedActiveRepSide,
        );
      }

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
}
