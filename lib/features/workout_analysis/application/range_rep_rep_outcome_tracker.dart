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
  RangeRepRepSummary? _lastRangeRepRepSummaryCandidate;
  RangeRepValidationResult? _lastRangeRepValidationResult;
  int? _lastRangeRepValidatedRepIndex;
  int _rangeRepValidatedCount = 0;
  int _rangeRepLowConfidenceCount = 0;
  int _rangeRepInvalidCount = 0;

  RangeRepRepSummary? get lastRangeRepRepSummaryCandidate =>
      _lastRangeRepRepSummaryCandidate;
  RangeRepValidationResult? get lastRangeRepValidationResult =>
      _lastRangeRepValidationResult;
  int? get lastRangeRepValidatedRepIndex => _lastRangeRepValidatedRepIndex;
  int get rangeRepValidatedCount => _rangeRepValidatedCount;
  int get rangeRepLowConfidenceCount => _rangeRepLowConfidenceCount;
  int get rangeRepInvalidCount => _rangeRepInvalidCount;

  void trackRepContext({
    required EngineKind engineKind,
    required RangeRepDiagnosticsSnapshot diagnostics,
    required String? selectedSideLabel,
    bool markCoverageDrop = false,
  }) {
    if (engineKind != EngineKind.rangeRep ||
        !_isRangeRepRepContextActive(diagnostics)) {
      return;
    }

    if (markCoverageDrop) {
      _activeRangeRepHadCoverageDrop = true;
    }

    if (selectedSideLabel == null) {
      return;
    }

    if (_activeRangeRepSelectedSideLabel != null &&
        _activeRangeRepSelectedSideLabel != selectedSideLabel) {
      _activeRangeRepSwitchedSideDuringRep = true;
    }

    _activeRangeRepSelectedSideLabel = selectedSideLabel;
  }

  void activateCompletedRepOutcomeIfAny({
    required EngineKind engineKind,
    required String analysisKindLabel,
    required RangeRepCompletedRepCoreData? completedRepCoreData,
  }) {
    if (engineKind != EngineKind.rangeRep || completedRepCoreData == null) {
      return;
    }

    final summaryCandidate = RangeRepRepSummary(
      repIndex: completedRepCoreData.repIndex,
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
    );
    final validationOutcome = RangeRepValidationOutcome(
      summary: summaryCandidate,
      result: _validationPolicy.evaluate(summaryCandidate),
    );
    _activateRangeRepValidationOutcome(validationOutcome);
    resetRepContext();
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
    if (clearCandidate) {
      _lastRangeRepRepSummaryCandidate = null;
      _lastRangeRepValidationResult = null;
      _lastRangeRepValidatedRepIndex = null;
    }
  }

  void _activateRangeRepValidationOutcome(RangeRepValidationOutcome outcome) {
    if (_lastRangeRepValidatedRepIndex == outcome.repIndex) {
      return;
    }

    _lastRangeRepRepSummaryCandidate = outcome.summary;
    _lastRangeRepValidationResult = outcome.result;
    _lastRangeRepValidatedRepIndex = outcome.repIndex;

    switch (outcome.status) {
      case RangeRepValidationStatus.valid:
        _rangeRepValidatedCount += 1;
        break;
      case RangeRepValidationStatus.lowConfidence:
        _rangeRepLowConfidenceCount += 1;
        break;
      case RangeRepValidationStatus.invalid:
        _rangeRepInvalidCount += 1;
        break;
    }
  }

  bool _isRangeRepRepContextActive(RangeRepDiagnosticsSnapshot diagnostics) {
    return diagnostics.hasActiveRepPhase || diagnostics.hasPendingTransition;
  }
}
