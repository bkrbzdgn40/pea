import '../domain/models/hold_side.dart';

enum HoldSideSelectionReason {
  selectedPreferredSide,
  replacedUnavailableCurrentSide,
  keptPreviousSide,
  confirmedSwitch,
}

class HoldSideSelectionResult {
  const HoldSideSelectionResult({
    required this.selectedSide,
    required this.acceptedSides,
    required this.reason,
  });

  final HoldSide selectedSide;
  final Set<HoldSide> acceptedSides;
  final HoldSideSelectionReason reason;

  String get debugLabel {
    switch (reason) {
      case HoldSideSelectionReason.selectedPreferredSide:
        return 'selected preferred side';
      case HoldSideSelectionReason.replacedUnavailableCurrentSide:
        return 'replaced unavailable current side';
      case HoldSideSelectionReason.keptPreviousSide:
        return 'kept previous side';
      case HoldSideSelectionReason.confirmedSwitch:
        return 'confirmed switch';
    }
  }
}

class HoldSideStabilizer {
  HoldSideStabilizer({this.sideSwitchConfirmationFrames = 2});

  final int sideSwitchConfirmationFrames;

  HoldSide? _pendingSideSwitch;
  int _pendingSideSwitchWins = 0;
  String? _status;

  String? get status => _status;

  HoldSideSelectionResult stabilizeSelection({
    required HoldSide preferredSide,
    required Set<HoldSide> acceptedSides,
    required HoldSide? currentSide,
  }) {
    if (!acceptedSides.contains(preferredSide)) {
      throw ArgumentError.value(
        preferredSide,
        'preferredSide',
        'preferredSide must be included in acceptedSides.',
      );
    }

    final immutableAcceptedSides = Set<HoldSide>.unmodifiable(acceptedSides);
    if (currentSide == null) {
      _resetPendingSwitch(keepStatus: true);
      _status = 'acquire:${preferredSide.name}';
      return HoldSideSelectionResult(
        selectedSide: preferredSide,
        acceptedSides: immutableAcceptedSides,
        reason: HoldSideSelectionReason.selectedPreferredSide,
      );
    }

    if (!acceptedSides.contains(currentSide)) {
      _resetPendingSwitch(keepStatus: true);
      _status = 'replace:${preferredSide.name}';
      return HoldSideSelectionResult(
        selectedSide: preferredSide,
        acceptedSides: immutableAcceptedSides,
        reason: HoldSideSelectionReason.replacedUnavailableCurrentSide,
      );
    }

    if (currentSide == preferredSide) {
      _resetPendingSwitch(keepStatus: true);
      _status = 'stay:${currentSide.name}';
      return HoldSideSelectionResult(
        selectedSide: currentSide,
        acceptedSides: immutableAcceptedSides,
        reason: HoldSideSelectionReason.keptPreviousSide,
      );
    }

    if (_pendingSideSwitch == preferredSide) {
      _pendingSideSwitchWins += 1;
    } else {
      _pendingSideSwitch = preferredSide;
      _pendingSideSwitchWins = 1;
    }

    if (_pendingSideSwitchWins >= sideSwitchConfirmationFrames) {
      _resetPendingSwitch(keepStatus: true);
      _status = 'confirm:${preferredSide.name}';
      return HoldSideSelectionResult(
        selectedSide: preferredSide,
        acceptedSides: immutableAcceptedSides,
        reason: HoldSideSelectionReason.confirmedSwitch,
      );
    }

    _status =
        'hold:${preferredSide.name} '
        '$_pendingSideSwitchWins/$sideSwitchConfirmationFrames';
    return HoldSideSelectionResult(
      selectedSide: currentSide,
      acceptedSides: immutableAcceptedSides,
      reason: HoldSideSelectionReason.keptPreviousSide,
    );
  }

  void reset() {
    _resetPendingSwitch();
  }

  void _resetPendingSwitch({bool keepStatus = false}) {
    _pendingSideSwitch = null;
    _pendingSideSwitchWins = 0;
    if (!keepStatus) {
      _status = null;
    }
  }
}
