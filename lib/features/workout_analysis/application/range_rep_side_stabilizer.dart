import 'exercise_metrics.dart';
import 'range_rep_side_policy.dart';

/// Stabilizes range-rep side selection across frame-to-frame coverage churn.
class RangeRepSideStabilizer {
  RangeRepSideStabilizer({
    this.sideSwitchConfirmationFrames = 2,
    this.sideConfidenceSwitchMargin = 0.15,
    this.repSideSwitchConfirmationFrames = 2,
    this.repSideConfidenceSwitchMargin = 0.20,
  });

  final int sideSwitchConfirmationFrames;
  final double sideConfidenceSwitchMargin;
  final int repSideSwitchConfirmationFrames;
  final double repSideConfidenceSwitchMargin;

  RangeRepSide? _pendingRangeRepSideSwitch;
  int _pendingRangeRepSideSwitchWins = 0;
  String? _hysteresisStatus;
  RangeRepSide? _activeRangeRepConsistentSide;
  RangeRepSide? _pendingRangeRepConsistentSideSwitch;
  int _pendingRangeRepConsistentSideSwitchWins = 0;
  String? _consistencyStatus;

  String? get hysteresisStatus => _hysteresisStatus;
  String? get consistencyStatus => _consistencyStatus;

  RangeRepSideSelection stabilizeSelection({
    required RangeRepSideSelection selection,
    required RangeRepSide? currentSide,
    required bool hasActiveRepContext,
  }) {
    final stabilizedSelection = _applyHysteresis(
      selection: selection,
      currentSide: currentSide,
    );
    return _applyRepConsistency(
      selection: stabilizedSelection,
      hasActiveRepContext: hasActiveRepContext,
    );
  }

  void reset() {
    _resetHysteresis();
    _resetRepConsistency();
  }

  RangeRepSideSelection _applyHysteresis({
    required RangeRepSideSelection selection,
    required RangeRepSide? currentSide,
  }) {
    final selectedSide = selection.selectedSide;

    if (selection.reason == RangeRepSideSelectionReason.lockedActiveRepSide) {
      _resetHysteresis(keepStatus: true);
      _hysteresisStatus = 'locked:${_sideLabel(selectedSide) ?? '--'}';
      return selection;
    }

    if (selection.reason == RangeRepSideSelectionReason.selectedMovingSide ||
        selection.reason == RangeRepSideSelectionReason.switchedToMovingSide ||
        selection.reason == RangeRepSideSelectionReason.keptMovingSide) {
      _resetHysteresis(keepStatus: true);
      _hysteresisStatus = 'movement:${_sideLabel(selectedSide) ?? '--'}';
      return selection;
    }

    if (currentSide == null) {
      _resetHysteresis(keepStatus: true);
      _hysteresisStatus = selectedSide == null
          ? 'unavailable'
          : 'acquire:${_sideLabel(selectedSide)}';
      return selection;
    }

    if (selectedSide == null || selectedSide == currentSide) {
      _resetHysteresis(keepStatus: true);
      _hysteresisStatus = 'stay:${_sideLabel(currentSide)}';
      return selection;
    }

    final currentMetrics = _sideMetricsFor(selection, currentSide);
    final alternateMetrics = _sideMetricsFor(selection, selectedSide);
    final coverageAdvantage =
        alternateMetrics.coverageScore - currentMetrics.coverageScore;
    final confidenceAdvantage =
        (alternateMetrics.sideConfidence ?? 0.0) -
        (currentMetrics.sideConfidence ?? 0.0);
    final currentSideUnusable =
        currentMetrics.coverageScore == 0 && alternateMetrics.coverageScore > 0;
    final clearCoverageWin = coverageAdvantage >= 2;
    final clearConfidenceStabilizedWin =
        coverageAdvantage >= 1 &&
        confidenceAdvantage >= sideConfidenceSwitchMargin;

    if (currentSideUnusable ||
        clearCoverageWin ||
        clearConfidenceStabilizedWin) {
      _resetHysteresis(keepStatus: true);
      _hysteresisStatus = 'switch:${_sideLabel(selectedSide)}';
      return selection;
    }

    if (_pendingRangeRepSideSwitch == selectedSide) {
      _pendingRangeRepSideSwitchWins += 1;
    } else {
      _pendingRangeRepSideSwitch = selectedSide;
      _pendingRangeRepSideSwitchWins = 1;
    }

    if (_pendingRangeRepSideSwitchWins >= sideSwitchConfirmationFrames) {
      _resetHysteresis(keepStatus: true);
      _hysteresisStatus = 'confirm:${_sideLabel(selectedSide)}';
      return selection;
    }

    _hysteresisStatus =
        'hold:${_sideLabel(selectedSide)} '
        '$_pendingRangeRepSideSwitchWins/$sideSwitchConfirmationFrames';
    return _selectionKeepingSide(selection, currentSide);
  }

  RangeRepSideSelection _applyRepConsistency({
    required RangeRepSideSelection selection,
    required bool hasActiveRepContext,
  }) {
    final selectedSide = selection.selectedSide;

    if (!hasActiveRepContext) {
      _resetRepConsistency();
      return selection;
    }

    if (_activeRangeRepConsistentSide == null) {
      if (selectedSide == null) {
        _consistencyStatus = 'await-side';
        return selection;
      }

      _activeRangeRepConsistentSide = selectedSide;
      _resetRepConsistency(keepAnchor: true, keepStatus: true);
      _consistencyStatus = 'anchor:${_sideLabel(selectedSide)}';
      return selection;
    }

    final anchoredSide = _activeRangeRepConsistentSide!;
    if (selectedSide == null || selectedSide == anchoredSide) {
      _resetRepConsistency(keepAnchor: true, keepStatus: true);
      _consistencyStatus = 'stay:${_sideLabel(anchoredSide)}';
      return _selectionKeepingSide(selection, anchoredSide);
    }

    final anchoredMetrics = _sideMetricsFor(selection, anchoredSide);
    final alternateMetrics = _sideMetricsFor(selection, selectedSide);
    final coverageAdvantage =
        alternateMetrics.coverageScore - anchoredMetrics.coverageScore;
    final confidenceAdvantage =
        (alternateMetrics.sideConfidence ?? 0.0) -
        (anchoredMetrics.sideConfidence ?? 0.0);
    final anchoredSideClearlyUnusable =
        anchoredMetrics.coverageScore == 0 &&
        alternateMetrics.coverageScore > 0;
    final strongRepSwitchCandidate =
        coverageAdvantage >= 2 ||
        (coverageAdvantage >= 1 &&
            confidenceAdvantage >= repSideConfidenceSwitchMargin);

    if (!anchoredSideClearlyUnusable && !strongRepSwitchCandidate) {
      _resetRepConsistency(keepAnchor: true, keepStatus: true);
      _consistencyStatus = 'keep:${_sideLabel(anchoredSide)}';
      return _selectionKeepingSide(selection, anchoredSide);
    }

    if (_pendingRangeRepConsistentSideSwitch == selectedSide) {
      _pendingRangeRepConsistentSideSwitchWins += 1;
    } else {
      _pendingRangeRepConsistentSideSwitch = selectedSide;
      _pendingRangeRepConsistentSideSwitchWins = 1;
    }

    if (_pendingRangeRepConsistentSideSwitchWins >=
        repSideSwitchConfirmationFrames) {
      _activeRangeRepConsistentSide = selectedSide;
      _resetRepConsistency(keepAnchor: true, keepStatus: true);
      _consistencyStatus = 'switch:${_sideLabel(selectedSide)}';
      return selection;
    }

    _consistencyStatus =
        'hold:${_sideLabel(selectedSide)} '
        '$_pendingRangeRepConsistentSideSwitchWins/'
        '$repSideSwitchConfirmationFrames';
    return _selectionKeepingSide(selection, anchoredSide);
  }

  RangeRepSideMetrics _sideMetricsFor(
    RangeRepSideSelection selection,
    RangeRepSide side,
  ) {
    switch (side) {
      case RangeRepSide.left:
        return selection.leftMetrics;
      case RangeRepSide.right:
        return selection.rightMetrics;
    }
  }

  RangeRepSideSelection _selectionKeepingSide(
    RangeRepSideSelection selection,
    RangeRepSide side,
  ) {
    final sideMetrics = _sideMetricsFor(selection, side);

    return RangeRepSideSelection(
      selectedSide: side,
      leftMetrics: selection.leftMetrics,
      rightMetrics: selection.rightMetrics,
      reason: sideMetrics.coverageScore > 0
          ? RangeRepSideSelectionReason.keptPreviousSide
          : RangeRepSideSelectionReason.keptPreviousSideWithoutCoverage,
    );
  }

  void _resetHysteresis({bool keepStatus = false}) {
    _pendingRangeRepSideSwitch = null;
    _pendingRangeRepSideSwitchWins = 0;
    if (!keepStatus) {
      _hysteresisStatus = null;
    }
  }

  void _resetRepConsistency({
    bool keepAnchor = false,
    bool keepStatus = false,
  }) {
    _pendingRangeRepConsistentSideSwitch = null;
    _pendingRangeRepConsistentSideSwitchWins = 0;
    if (!keepAnchor) {
      _activeRangeRepConsistentSide = null;
    }
    if (!keepStatus) {
      _consistencyStatus = null;
    }
  }

  String? _sideLabel(RangeRepSide? side) {
    switch (side) {
      case RangeRepSide.left:
        return 'left';
      case RangeRepSide.right:
        return 'right';
      case null:
        return null;
    }
  }
}
