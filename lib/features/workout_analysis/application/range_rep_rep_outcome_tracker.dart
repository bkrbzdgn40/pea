import '../domain/measurement_confidence_policy.dart';
import '../domain/models/measurement_confidence_breakdown.dart';
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
    MeasurementConfidencePolicy measurementConfidencePolicy =
        const MeasurementConfidencePolicy(),
  }) : _validationPolicy = validationPolicy,
       _measurementConfidencePolicy = measurementConfidencePolicy;

  final RangeRepValidationPolicy _validationPolicy;
  final MeasurementConfidencePolicy _measurementConfidencePolicy;

  bool _activeRangeRepHadCoverageDrop = false;
  bool _activeRangeRepSwitchedSideDuringRep = false;
  String? _activeRangeRepSelectedSideLabel;
  int _activeRangeRepObservedFrameCount = 0;
  int _activeRangeRepCoveredFrameCount = 0;
  final _MeasurementComponentAccumulator _landmarkLikelihood =
      _MeasurementComponentAccumulator();
  final _MeasurementComponentAccumulator _signalAvailability =
      _MeasurementComponentAccumulator();
  final _MeasurementComponentAccumulator _geometryPlausibility =
      _MeasurementComponentAccumulator();
  final _MeasurementComponentAccumulator _temporalContinuity =
      _MeasurementComponentAccumulator();
  final Set<MeasurementConfidenceIssue> _activeRangeRepConfidenceIssues =
      <MeasurementConfidenceIssue>{};
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

  MeasurementConfidenceBreakdown? get activeRepMeasurementConfidence {
    final coverageQuality = activeRepCoverageQuality;
    final hasMeasurementEvidence =
        _landmarkLikelihood.hasSamples ||
        _signalAvailability.hasSamples ||
        _geometryPlausibility.hasSamples ||
        _temporalContinuity.hasSamples;
    final hasContextIssue =
        _activeRangeRepHadCoverageDrop || _activeRangeRepSwitchedSideDuringRep;
    if (!hasMeasurementEvidence &&
        _activeRangeRepConfidenceIssues.isEmpty &&
        !hasContextIssue) {
      return null;
    }

    var signalAvailability = _signalAvailability.average;
    if (signalAvailability != null && coverageQuality != null) {
      signalAvailability = signalAvailability > coverageQuality
          ? coverageQuality
          : signalAvailability;
    }
    var temporalContinuity = _temporalContinuity.average;
    final issues = <MeasurementConfidenceIssue>{
      ..._activeRangeRepConfidenceIssues,
      if (_activeRangeRepHadCoverageDrop)
        MeasurementConfidenceIssue.coverageInterruption,
      if (_activeRangeRepSwitchedSideDuringRep)
        MeasurementConfidenceIssue.sideSwitchDuringRep,
    };
    if (_activeRangeRepSwitchedSideDuringRep && temporalContinuity != null) {
      temporalContinuity = 0.0;
    }

    return _measurementConfidencePolicy.evaluate(
      landmarkLikelihood: _landmarkLikelihood.average,
      signalAvailability: signalAvailability,
      geometryPlausibility: _geometryPlausibility.average,
      temporalContinuity: temporalContinuity,
      issues: issues.toList(growable: false),
    );
  }

  double? get activeRepConfidence => activeRepMeasurementConfidence?.combined;

  double? get activeRepCoverageQuality => _activeRangeRepObservedFrameCount == 0
      ? null
      : _activeRangeRepCoveredFrameCount / _activeRangeRepObservedFrameCount;

  void trackRepContext({
    required EngineKind engineKind,
    required RangeRepDiagnosticsSnapshot diagnostics,
    required String? selectedSideLabel,
    bool markCoverageDrop = false,
    MeasurementConfidenceBreakdown? frameMeasurementConfidence,
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
    final measurementConfidence =
        frameMeasurementConfidence ??
        (frameConfidence == null
            ? null
            : MeasurementConfidenceBreakdown.legacyScalar(
                frameConfidence.clamp(0.0, 1.0).toDouble(),
              ));
    if (measurementConfidence != null) {
      _landmarkLikelihood.add(measurementConfidence.landmarkLikelihood);
      _signalAvailability.add(measurementConfidence.signalAvailability);
      _geometryPlausibility.add(measurementConfidence.geometryPlausibility);
      _temporalContinuity.add(measurementConfidence.temporalContinuity);
      _activeRangeRepConfidenceIssues.addAll(measurementConfidence.issues);
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
      measurementConfidence: activeRepMeasurementConfidence,
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
      measurementConfidence: activeRepMeasurementConfidence,
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
    _landmarkLikelihood.reset();
    _signalAvailability.reset();
    _geometryPlausibility.reset();
    _temporalContinuity.reset();
    _activeRangeRepConfidenceIssues.clear();
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

class _MeasurementComponentAccumulator {
  double _total = 0.0;
  int _count = 0;

  bool get hasSamples => _count > 0;
  double? get average => _count == 0 ? null : _total / _count;

  void add(double? value) {
    if (value == null) {
      return;
    }
    _total += value;
    _count += 1;
  }

  void reset() {
    _total = 0.0;
    _count = 0;
  }
}
