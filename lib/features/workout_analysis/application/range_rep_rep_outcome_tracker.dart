import '../domain/models/range_rep_aborted_attempt_detection_data.dart';
import '../domain/models/range_rep_rep_summary.dart';
import '../domain/models/range_rep_validation_outcome.dart';
import '../domain/models/range_rep_validation_result.dart';
import '../domain/range_rep_diagnostics.dart';
import '../domain/range_rep_validation_policy.dart';
import 'engine_kind.dart';

/// Tracks completed range-rep outcomes and their validation telemetry.
class RangeRepRepOutcomeTracker {
  RangeRepRepOutcomeTracker({
    required RangeRepValidationPolicy validationPolicy,
  }) : _validationPolicy = validationPolicy;

  final RangeRepValidationPolicy _validationPolicy;

  bool _activeRangeRepHadCoverageDrop = false;
  bool _activeRangeRepSwitchedSideDuringRep = false;
  String? _activeRangeRepSelectedSideLabel;
  int _activeRangeRepObservedFrameCount = 0;
  int _activeRangeRepCoveredFrameCount = 0;
  double _activeRangeRepConfidenceTotal = 0.0;
  int _activeRangeRepConfidenceSampleCount = 0;
  RangeRepRepSummary? _lastRangeRepRepSummaryCandidate;
  RangeRepValidationResult? _lastRangeRepValidationResult;
  int? _lastRangeRepValidatedRepIndex;
  int? _lastRangeRepCompletedEngineRepIndex;
  int _rangeRepAttemptCount = 0;
  int _rangeRepAcceptedCount = 0;
  int _rangeRepValidatedCount = 0;
  int _rangeRepLowConfidenceCount = 0;
  int _rangeRepInvalidCount = 0;

  RangeRepRepSummary? get lastRangeRepRepSummaryCandidate =>
      _lastRangeRepRepSummaryCandidate;
  RangeRepValidationResult? get lastRangeRepValidationResult =>
      _lastRangeRepValidationResult;
  int? get lastRangeRepValidatedRepIndex => _lastRangeRepValidatedRepIndex;
  int get rangeRepAcceptedCount => _rangeRepAcceptedCount;
  int get rangeRepValidatedCount => _rangeRepValidatedCount;
  int get rangeRepLowConfidenceCount => _rangeRepLowConfidenceCount;
  int get rangeRepInvalidCount => _rangeRepInvalidCount;

  double? get activeRepConfidence => _activeRangeRepConfidenceSampleCount == 0
      ? null
      : _activeRangeRepConfidenceTotal / _activeRangeRepConfidenceSampleCount;

  double? get activeRepCoverageQuality => _activeRangeRepObservedFrameCount == 0
      ? null
      : _activeRangeRepCoveredFrameCount / _activeRangeRepObservedFrameCount;

  void trackRepContext({
    required EngineKind engineKind,
    required RangeRepDiagnosticsSnapshot diagnostics,
    required String? selectedSideLabel,
    bool markCoverageDrop = false,
    double? frameConfidence,
  }) {
    if (engineKind != EngineKind.rangeRep ||
        !_isRangeRepRepContextActive(diagnostics)) {
      return;
    }

    _activeRangeRepObservedFrameCount += 1;
    if (markCoverageDrop) {
      _activeRangeRepHadCoverageDrop = true;
    } else {
      _activeRangeRepCoveredFrameCount += 1;
    }
    if (frameConfidence != null) {
      _activeRangeRepConfidenceTotal += frameConfidence
          .clamp(0.0, 1.0)
          .toDouble();
      _activeRangeRepConfidenceSampleCount += 1;
    }

    if (selectedSideLabel == null) {
      return;
    }

    final lockedSideLabel = _activeRangeRepSelectedSideLabel;
    if (lockedSideLabel == null) {
      _activeRangeRepSelectedSideLabel = selectedSideLabel;
    } else if (lockedSideLabel != selectedSideLabel) {
      _activeRangeRepSwitchedSideDuringRep = true;
    }
  }

  RangeRepValidationOutcome? activateCompletedRepOutcomeIfAny({
    required EngineKind engineKind,
    required String analysisKindLabel,
    required RangeRepCompletedRepCoreData? completedRepCoreData,
  }) {
    if (engineKind != EngineKind.rangeRep || completedRepCoreData == null) {
      return null;
    }
    if (_lastRangeRepCompletedEngineRepIndex == completedRepCoreData.repIndex) {
      return null;
    }

    final attemptIndex = _rangeRepAttemptCount + 1;
    final summaryCandidate = RangeRepRepSummary(
      repIndex: attemptIndex,
      minAngle: completedRepCoreData.minAngle,
      worstFormMetric: completedRepCoreData.worstFormMetric,
      descentDuration: completedRepCoreData.descentDuration,
      ascentDuration: completedRepCoreData.ascentDuration,
      hadFormViolation: completedRepCoreData.hadFormViolation,
      hadCoverageDrop: _activeRangeRepHadCoverageDrop,
      switchedSideDuringRep: _activeRangeRepSwitchedSideDuringRep,
      completedPhaseSequence: completedRepCoreData.completedPhaseSequence,
      selectedSideLabel: _activeRangeRepSelectedSideLabel,
      analysisKindLabel: analysisKindLabel,
      startAngle: completedRepCoreData.startAngle,
      primaryRom: completedRepCoreData.primaryRom,
      confidence: activeRepConfidence,
      coverageQuality: activeRepCoverageQuality,
      totalRepDuration: completedRepCoreData.totalRepDuration,
    );
    final validationOutcome = RangeRepValidationOutcome(
      attemptIndex: attemptIndex,
      summary: summaryCandidate,
      result: _validationPolicy.evaluate(summaryCandidate),
    );
    final didActivate = _activateRangeRepValidationOutcome(validationOutcome);
    if (didActivate) {
      _lastRangeRepCompletedEngineRepIndex = completedRepCoreData.repIndex;
    }
    resetRepContext();
    return didActivate ? validationOutcome : null;
  }

  RangeRepValidationOutcome? activateShallowAbortedRepOutcomeIfAny({
    required EngineKind engineKind,
    required String analysisKindLabel,
    required RangeRepAbortedAttemptDetectionData? abortedAttemptData,
    required double worstFormMetric,
    required bool hadFormViolation,
  }) {
    if (engineKind != EngineKind.rangeRep ||
        abortedAttemptData == null ||
        !_validationPolicy.config.invalidateAbortToNeutralAsInsufficientRom) {
      return null;
    }

    final attemptIndex = _rangeRepAttemptCount + 1;
    final summaryCandidate = RangeRepRepSummary(
      repIndex: attemptIndex,
      minAngle: abortedAttemptData.minAngle,
      worstFormMetric: worstFormMetric,
      descentDuration: abortedAttemptData.descentDuration,
      ascentDuration: Duration.zero,
      hadFormViolation: hadFormViolation,
      hadCoverageDrop: _activeRangeRepHadCoverageDrop,
      switchedSideDuringRep: _activeRangeRepSwitchedSideDuringRep,
      completedPhaseSequence: false,
      selectedSideLabel: _activeRangeRepSelectedSideLabel,
      analysisKindLabel: analysisKindLabel,
      startAngle: abortedAttemptData.startAngle,
      primaryRom: abortedAttemptData.primaryRom,
      confidence: activeRepConfidence,
      coverageQuality: activeRepCoverageQuality,
    );
    final validationOutcome = RangeRepValidationOutcome(
      attemptIndex: attemptIndex,
      summary: summaryCandidate,
      result: _validationPolicy.evaluateShallowAbort(),
    );
    final didActivate = _activateRangeRepValidationOutcome(validationOutcome);
    resetRepContext();
    return didActivate ? validationOutcome : null;
  }

  void resetRepContextIfCycleEnded({
    required RangeRepDiagnosticsSnapshot previousDiagnostics,
    required RangeRepDiagnosticsSnapshot currentDiagnostics,
    required bool didCompleteRep,
  }) {
    if (didCompleteRep ||
        !_isRangeRepRepContextActive(previousDiagnostics) ||
        _isRangeRepRepContextActive(currentDiagnostics)) {
      return;
    }

    resetRepContext();
  }

  void resetRepContext({bool clearCandidate = false}) {
    _activeRangeRepHadCoverageDrop = false;
    _activeRangeRepSwitchedSideDuringRep = false;
    _activeRangeRepSelectedSideLabel = null;
    _activeRangeRepObservedFrameCount = 0;
    _activeRangeRepCoveredFrameCount = 0;
    _activeRangeRepConfidenceTotal = 0.0;
    _activeRangeRepConfidenceSampleCount = 0;
    if (clearCandidate) {
      _lastRangeRepRepSummaryCandidate = null;
      _lastRangeRepValidationResult = null;
      _lastRangeRepValidatedRepIndex = null;
    }
  }

  bool _activateRangeRepValidationOutcome(RangeRepValidationOutcome outcome) {
    if (outcome.attemptIndex != _rangeRepAttemptCount + 1) {
      return false;
    }

    _rangeRepAttemptCount = outcome.attemptIndex;
    _lastRangeRepRepSummaryCandidate = outcome.summary;
    _lastRangeRepValidationResult = outcome.result;
    _lastRangeRepValidatedRepIndex = outcome.attemptIndex;

    switch (outcome.status) {
      case RangeRepValidationStatus.valid:
        _rangeRepAcceptedCount += 1;
        _rangeRepValidatedCount += 1;
        break;
      case RangeRepValidationStatus.lowConfidence:
        _rangeRepAcceptedCount += 1;
        _rangeRepLowConfidenceCount += 1;
        break;
      case RangeRepValidationStatus.invalid:
        _rangeRepInvalidCount += 1;
        break;
    }
    return true;
  }

  bool _isRangeRepRepContextActive(RangeRepDiagnosticsSnapshot diagnostics) {
    return diagnostics.hasRepContext;
  }
}
