import 'analysis_visibility_gap_window.dart';
import 'legacy_range_rep_phase_quality_policy.dart';
import 'legacy_range_rep_scorer.dart';
import 'legacy_range_rep_technique_evaluator.dart';
import 'models/exercise_config.dart';
import 'models/analysis_frame.dart';
import 'models/range_rep_completed_rep_detection_data.dart';
import 'models/range_rep_confirmed_transition.dart';
import 'models/range_rep_contract.dart';
import 'models/range_rep_engine_frame_result.dart';
import 'models/range_rep_feedback_code.dart';
import 'models/range_rep_technique_assessment.dart';
import 'models/rep_score_breakdown.dart';
import 'range_rep_analysis_engine.dart';
import 'range_rep_diagnostics.dart';

enum MovementPhase { neutral, descending, peak, ascending }

const Duration _descentConfirmationDuration = Duration(milliseconds: 80);
const Duration _peakConfirmationDuration = Duration(milliseconds: 80);
const Duration _ascentConfirmationDuration = Duration(milliseconds: 80);
const Duration _neutralConfirmationDuration = Duration(milliseconds: 100);

const double _descentEntryMargin = 3.0;
const double _peakEntryMargin = 3.0;
const double _peakExitMargin = 8.0;

enum _PhaseTransition {
  acquireNeutral,
  startDescending,
  reachPeak,
  startAscending,
  abortToNeutral,
  completeRep,
}

class _RangeRepLifecycleFacts {
  const _RangeRepLifecycleFacts({
    this.repStarted = false,
    this.repAborted = false,
    this.completedRepDetectionData,
    this.completedRepCoreData,
    this.confirmedTransition,
    this.observedRepPhases = const <RangeRepPhase>[],
  });

  final bool repStarted;
  final bool repAborted;
  final RangeRepCompletedRepDetectionData? completedRepDetectionData;
  final RangeRepCompletedRepCoreData? completedRepCoreData;
  final RangeRepConfirmedTransition? confirmedTransition;
  final List<RangeRepPhase> observedRepPhases;
}

class _RangeRepCompletionFacts {
  const _RangeRepCompletionFacts({
    required this.detectionData,
    this.compatibilityCoreData,
  });

  final RangeRepCompletedRepDetectionData detectionData;
  final RangeRepCompletedRepCoreData? compatibilityCoreData;
}

extension _PhaseTransitionX on _PhaseTransition {
  RangeRepConfirmedTransition confirmedAt(DateTime effectiveAt) {
    final type = switch (this) {
      _PhaseTransition.acquireNeutral =>
        RangeRepConfirmedTransitionType.acquireNeutral,
      _PhaseTransition.startDescending =>
        RangeRepConfirmedTransitionType.startDescending,
      _PhaseTransition.reachPeak => RangeRepConfirmedTransitionType.reachPeak,
      _PhaseTransition.startAscending =>
        RangeRepConfirmedTransitionType.startAscending,
      _PhaseTransition.abortToNeutral =>
        RangeRepConfirmedTransitionType.abortToNeutral,
      _PhaseTransition.completeRep =>
        RangeRepConfirmedTransitionType.completeRep,
    };
    return RangeRepConfirmedTransition(type: type, effectiveAt: effectiveAt);
  }

  Duration get confirmationDuration {
    switch (this) {
      case _PhaseTransition.acquireNeutral:
        return _neutralConfirmationDuration;
      case _PhaseTransition.startDescending:
        return _descentConfirmationDuration;
      case _PhaseTransition.reachPeak:
        return _peakConfirmationDuration;
      case _PhaseTransition.startAscending:
        return _ascentConfirmationDuration;
      case _PhaseTransition.abortToNeutral:
      case _PhaseTransition.completeRep:
        return _neutralConfirmationDuration;
    }
  }

  String get debugLabel {
    switch (this) {
      case _PhaseTransition.acquireNeutral:
        return rangeRepAwaitNeutralPendingTransitionLabel;
      case _PhaseTransition.startDescending:
        return 'neutral -> descending';
      case _PhaseTransition.reachPeak:
        return 'descending -> peak';
      case _PhaseTransition.startAscending:
        return 'peak -> ascending';
      case _PhaseTransition.abortToNeutral:
        return 'descending -> neutral';
      case _PhaseTransition.completeRep:
        return 'ascending -> neutral';
    }
  }
}

class RepResult {
  final int index;
  final double rom;
  final Duration descentTime;
  final Duration ascentTime;
  final double score;

  RepResult({
    required this.index,
    required this.rom,
    required this.descentTime,
    required this.ascentTime,
    required this.score,
  });
}

class _MutableRangeRepPhaseQuality {
  DateTime? _startedAt;
  int _completedDurationMs = 0;
  double? _minPrimaryMetric;
  double? _maxPrimaryMetric;
  double? _worstFormMetric;
  bool _hadFormViolation = false;
  bool _hasData = false;

  void start({
    required DateTime startedAt,
    required double primaryMetric,
    required double formMetric,
    required bool hadFormViolation,
  }) {
    reset();
    _startedAt = startedAt;
    record(
      primaryMetric: primaryMetric,
      formMetric: formMetric,
      hadFormViolation: hadFormViolation,
    );
  }

  void record({
    required double primaryMetric,
    required double formMetric,
    required bool hadFormViolation,
  }) {
    _hasData = true;
    _minPrimaryMetric = _minPrimaryMetric == null
        ? primaryMetric
        : (primaryMetric < _minPrimaryMetric!
              ? primaryMetric
              : _minPrimaryMetric);
    _maxPrimaryMetric = _maxPrimaryMetric == null
        ? primaryMetric
        : (primaryMetric > _maxPrimaryMetric!
              ? primaryMetric
              : _maxPrimaryMetric);
    _worstFormMetric = _worstFormMetric == null
        ? formMetric
        : (formMetric < _worstFormMetric! ? formMetric : _worstFormMetric);
    if (hadFormViolation) {
      _hadFormViolation = true;
    }
  }

  void complete(DateTime endedAt) {
    if (_startedAt == null) {
      return;
    }

    final durationMs = endedAt.difference(_startedAt!).inMilliseconds;
    _completedDurationMs = durationMs < 0 ? 0 : durationMs;
  }

  void shiftStartedAt(Duration delta) {
    if (_startedAt == null || delta == Duration.zero) {
      return;
    }
    _startedAt = _startedAt!.add(delta);
  }

  RangeRepPhaseQualitySnapshot snapshot({
    required DateTime now,
    required bool isActive,
  }) {
    if (!_hasData) {
      return const RangeRepPhaseQualitySnapshot();
    }

    var durationMs = _completedDurationMs;
    if (isActive && _startedAt != null) {
      durationMs = now.difference(_startedAt!).inMilliseconds;
      if (durationMs < 0) {
        durationMs = 0;
      }
    }

    return RangeRepPhaseQualitySnapshot(
      hasData: true,
      durationMs: durationMs,
      minPrimaryMetric: _minPrimaryMetric,
      maxPrimaryMetric: _maxPrimaryMetric,
      worstFormMetric: _worstFormMetric,
      hadFormViolation: _hadFormViolation,
    );
  }

  void reset() {
    _startedAt = null;
    _completedDurationMs = 0;
    _minPrimaryMetric = null;
    _maxPrimaryMetric = null;
    _worstFormMetric = null;
    _hadFormViolation = false;
    _hasData = false;
  }
}

/// Current range-rep engine backing the workout analysis flow.
class RangeRepEngine implements RangeRepAnalysisEngine {
  final ExerciseConfig config;
  final DateTime Function() _now;
  final LegacyRangeRepScorer _scorer = const LegacyRangeRepScorer();
  final LegacyRangeRepTechniqueEvaluator _techniqueEvaluator =
      const LegacyRangeRepTechniqueEvaluator();
  final LegacyRangeRepPhaseQualityPolicy _phaseQualityPolicy =
      const LegacyRangeRepPhaseQualityPolicy();

  MovementPhase state = MovementPhase.neutral;
  bool _isArmed = false;
  @override
  int repCount = 0;
  bool isFormBad = false;

  // Compatibility ROM value for the most recently completed repetition.
  double _lastRepRom = 180.0;
  double lastRepScore = 0.0;
  RepScoreBreakdown? lastRepScoreBreakdown;
  RangeRepCompletedRepCoreData? lastCompletedRepCoreData;
  RangeRepCompletedRepCoreData? _pendingCompletedRepCoreData;
  late String feedback;
  RangeRepFeedbackCode? _feedbackCode;

  DateTime? _descentStartTime;
  DateTime? _peakStartTime;
  DateTime? _ascentStartTime;
  final AnalysisVisibilityGapWindow _briefVisibilityGapWindow =
      AnalysisVisibilityGapWindow(
        graceDuration: rangeRepVisibilityGapGraceDuration,
      );
  MovementPhase? _briefVisibilityGapFrozenPhase;
  bool _briefVisibilityGapWasArmed = false;

  Duration lastDescentTime = Duration.zero;
  Duration lastAscentTime = Duration.zero;

  double _currentRepMinAngle = 180.0;
  double _currentRepWorstBackAngle = 180.0;
  bool _currentRepHadFormViolation = false;
  _PhaseTransition? _pendingTransition;
  DateTime? _pendingTransitionStartedAt;
  String? _lastConfirmedTransitionLabel;
  final _MutableRangeRepPhaseQuality _descendingPhaseQuality =
      _MutableRangeRepPhaseQuality();
  final _MutableRangeRepPhaseQuality _peakPhaseQuality =
      _MutableRangeRepPhaseQuality();
  final _MutableRangeRepPhaseQuality _ascendingPhaseQuality =
      _MutableRangeRepPhaseQuality();
  RangeRepPhaseQualityTelemetry? _lastCompletedPhaseQualityTelemetry;

  RangeRepEngine({required this.config, DateTime Function()? now})
    : _now = now ?? DateTime.now {
    _disarm();
  }

  @override
  double get lastRepRom => _lastRepRom;

  RangeRepFeedbackCode? get feedbackCode => _feedbackCode;

  RangeRepCompletedRepCoreData? consumeCompletedRepCoreData() {
    final completedRepCoreData = _pendingCompletedRepCoreData;
    _pendingCompletedRepCoreData = null;
    return completedRepCoreData;
  }

  @override
  String get phaseLabel =>
      _isArmed ? state.name.toUpperCase() : rangeRepAwaitNeutralPhaseLabel;

  @override
  RangeRepDiagnosticsSnapshot get detectionDiagnosticsSnapshot {
    return RangeRepDiagnosticsSnapshot(
      phaseGateStatus: _phaseGateStatus,
      hasActiveRepPhase: _isArmed && state != MovementPhase.neutral,
      hasPendingTransition: _pendingTransition != null,
      pendingTransitionLabel: _pendingTransition?.debugLabel,
      lastConfirmedTransitionLabel: _lastConfirmedTransitionLabel,
    );
  }

  RangeRepDiagnosticsSnapshot get diagnosticsSnapshot {
    final now = _now();
    final phaseQualityTelemetry =
        state == MovementPhase.neutral && _pendingTransition == null
        ? (_lastCompletedPhaseQualityTelemetry ?? _phaseQualityTelemetry(now))
        : _phaseQualityTelemetry(now);
    final descendingPhaseAssessment = _assessPhaseQuality(
      phase: MovementPhase.descending,
      phaseQuality: phaseQualityTelemetry.descendingPhaseQuality,
      isActivePhase: state == MovementPhase.descending,
    );
    final peakPhaseAssessment = _assessPhaseQuality(
      phase: MovementPhase.peak,
      phaseQuality: phaseQualityTelemetry.peakPhaseQuality,
      isActivePhase: state == MovementPhase.peak,
    );
    final ascendingPhaseAssessment = _assessPhaseQuality(
      phase: MovementPhase.ascending,
      phaseQuality: phaseQualityTelemetry.ascendingPhaseQuality,
      isActivePhase: state == MovementPhase.ascending,
    );

    return RangeRepDiagnosticsSnapshot(
      currentRepWorstBackAngle: _currentRepWorstBackAngle,
      currentRepHadFormViolation: _currentRepHadFormViolation,
      phaseGateStatus: _phaseGateStatus,
      hasActiveRepPhase: _isArmed && state != MovementPhase.neutral,
      hasPendingTransition: _pendingTransition != null,
      pendingTransitionLabel: _pendingTransition?.debugLabel,
      lastConfirmedTransitionLabel: _lastConfirmedTransitionLabel,
      lastRepScoreBreakdown: lastRepScoreBreakdown,
      lastCompletedRepCoreData: lastCompletedRepCoreData,
      descendingPhaseQuality: phaseQualityTelemetry.descendingPhaseQuality,
      peakPhaseQuality: phaseQualityTelemetry.peakPhaseQuality,
      ascendingPhaseQuality: phaseQualityTelemetry.ascendingPhaseQuality,
      descendingPhaseAssessment: descendingPhaseAssessment,
      peakPhaseAssessment: peakPhaseAssessment,
      ascendingPhaseAssessment: ascendingPhaseAssessment,
      phaseFeedbackCandidate: _phaseFeedbackCodeCandidate(
        descendingPhaseAssessment: descendingPhaseAssessment,
        peakPhaseAssessment: peakPhaseAssessment,
        ascendingPhaseAssessment: ascendingPhaseAssessment,
      )?.code,
    );
  }

  @override
  RangeRepEngineFrameResult updateDetectionFrame({
    required double primaryMetric,
  }) {
    return _updateFrame(
      primaryMetric: primaryMetric,
      calculateCompatibilityScore: false,
    );
  }

  /// Legacy compatibility path that retains form, scoring, and feedback state.
  @override
  void update(AnalysisFrame frame) {
    final techniqueAssessment = _techniqueEvaluator.evaluate(
      formMetric: frame.formMetric,
      formThreshold: config.formThreshold,
    );
    _updateFrame(
      primaryMetric: frame.primaryMetric,
      compatibilityFormMetric: frame.formMetric,
      techniqueAssessment: techniqueAssessment,
      calculateCompatibilityScore: true,
    );
  }

  /// Compatibility path for direct callers that supply technique decisions.
  RangeRepEngineFrameResult updateWithTechniqueAssessment(
    AnalysisFrame frame, {
    required RangeRepTechniqueAssessment techniqueAssessment,
  }) {
    return _updateFrame(
      primaryMetric: frame.primaryMetric,
      compatibilityFormMetric: frame.formMetric,
      techniqueAssessment: techniqueAssessment,
      calculateCompatibilityScore: false,
    );
  }

  RangeRepEngineFrameResult _updateFrame({
    required double primaryMetric,
    double? compatibilityFormMetric,
    RangeRepTechniqueAssessment? techniqueAssessment,
    required bool calculateCompatibilityScore,
  }) {
    final wasArmedAtFrameStart = _isArmed;
    final tracksCompatibilityTechnique =
        compatibilityFormMetric != null && techniqueAssessment != null;
    final hasTechniqueViolation = techniqueAssessment?.hasObservations ?? false;
    if (tracksCompatibilityTechnique) {
      if (_isArmed) {
        _checkForm(hasTechniqueViolation);
      } else {
        isFormBad = false;
        _setFeedback(RangeRepFeedbackCode.awaitNeutral);
      }
    }
    final lifecycleFacts = _processState(
      primaryMetric,
      compatibilityFormMetric: compatibilityFormMetric,
      hasTechniqueViolation: hasTechniqueViolation,
      tracksCompatibilityTechnique: tracksCompatibilityTechnique,
      calculateCompatibilityScore: calculateCompatibilityScore,
    );
    return RangeRepEngineFrameResult(
      wasArmedAtFrameStart: wasArmedAtFrameStart,
      isArmedAfterUpdate: _isArmed,
      repStarted: lifecycleFacts.repStarted,
      repAborted: lifecycleFacts.repAborted,
      completedRepDetectionData: lifecycleFacts.completedRepDetectionData,
      completedRepCoreData: lifecycleFacts.completedRepCoreData,
      confirmedTransition: lifecycleFacts.confirmedTransition,
      observedRepPhases: lifecycleFacts.observedRepPhases,
    );
  }

  _RangeRepLifecycleFacts _processState(
    double angle, {
    required double? compatibilityFormMetric,
    required bool hasTechniqueViolation,
    required bool tracksCompatibilityTechnique,
    required bool calculateCompatibilityScore,
  }) {
    final now = _now();

    if (!_isArmed) {
      final armedAt = _confirmTransition(
        transition: _PhaseTransition.acquireNeutral,
        condition: angle > _neutralReturnThreshold,
        now: now,
      );
      if (armedAt != null) {
        _isArmed = true;
        state = MovementPhase.neutral;
        _lastConfirmedTransitionLabel =
            _PhaseTransition.acquireNeutral.debugLabel;
        if (tracksCompatibilityTechnique) {
          _setFeedback(RangeRepFeedbackCode.ready);
        }
      }
      return _RangeRepLifecycleFacts(
        confirmedTransition: armedAt == null
            ? null
            : _PhaseTransition.acquireNeutral.confirmedAt(armedAt),
      );
    }

    var repStarted = false;
    var repAborted = false;
    RangeRepCompletedRepDetectionData? completedRepDetectionData;
    RangeRepCompletedRepCoreData? completedRepCoreData;
    RangeRepConfirmedTransition? confirmedTransition;
    final observedRepPhases = <RangeRepPhase>[];

    // Aborted descents reset to neutral without counting a repetition.
    switch (state) {
      case MovementPhase.neutral:
        final confirmedAt = _confirmTransition(
          transition: _PhaseTransition.startDescending,
          condition: angle < _descentEntryThreshold,
          now: now,
        );
        if (confirmedAt != null) {
          confirmedTransition = _PhaseTransition.startDescending.confirmedAt(
            confirmedAt,
          );
          repStarted = true;
          observedRepPhases.add(RangeRepPhase.descending);
          state = MovementPhase.descending;
          _descentStartTime = confirmedAt;
          _startDetectionRepMetrics(angle);
          if (tracksCompatibilityTechnique) {
            _startCompatibilityRepMetrics(
              compatibilityFormMetric!,
              hasTechniqueViolation: hasTechniqueViolation,
              phaseStartedAt: confirmedAt,
              primaryMetric: angle,
            );
            _setFeedback(RangeRepFeedbackCode.descend);
          }
        }
        break;

      case MovementPhase.descending:
        observedRepPhases.add(RangeRepPhase.descending);
        if (tracksCompatibilityTechnique) {
          _trackRepForm(compatibilityFormMetric!, hasTechniqueViolation);
          _recordPhaseObservation(
            phase: MovementPhase.descending,
            primaryMetric: angle,
            formMetric: compatibilityFormMetric,
            hasTechniqueViolation: hasTechniqueViolation,
          );
        }
        if (angle < _currentRepMinAngle) _currentRepMinAngle = angle;

        final peakConfirmedAt = _confirmTransition(
          transition: _PhaseTransition.reachPeak,
          condition: angle < _peakEntryThreshold,
          now: now,
        );
        if (peakConfirmedAt != null) {
          confirmedTransition = _PhaseTransition.reachPeak.confirmedAt(
            peakConfirmedAt,
          );
          observedRepPhases.add(RangeRepPhase.peak);
          state = MovementPhase.peak;
          _peakStartTime = peakConfirmedAt;
          if (_descentStartTime != null) {
            lastDescentTime = _peakStartTime!.difference(_descentStartTime!);
          }
          if (tracksCompatibilityTechnique) {
            _completePhaseTelemetry(
              phase: MovementPhase.descending,
              phaseEndedAt: peakConfirmedAt,
            );
            _beginPhaseTelemetry(
              phase: MovementPhase.peak,
              phaseStartedAt: peakConfirmedAt,
              primaryMetric: angle,
              formMetric: compatibilityFormMetric!,
              hasTechniqueViolation: hasTechniqueViolation,
            );
            _setFeedback(RangeRepFeedbackCode.ascend);
          }
        } else {
          final abortConfirmedAt = _confirmTransition(
            transition: _PhaseTransition.abortToNeutral,
            condition: angle > _neutralReturnThreshold,
            now: now,
          );
          if (abortConfirmedAt != null) {
            confirmedTransition = _PhaseTransition.abortToNeutral.confirmedAt(
              abortConfirmedAt,
            );
            repAborted = true;
            state = MovementPhase.neutral;
            _resetDetectionRepMetrics();
            if (tracksCompatibilityTechnique) {
              _resetCompatibilityRepMetrics();
              _setFeedback(RangeRepFeedbackCode.repIncomplete);
            }
          }
        }
        break;

      case MovementPhase.peak:
        observedRepPhases.add(RangeRepPhase.peak);
        if (tracksCompatibilityTechnique) {
          _trackRepForm(compatibilityFormMetric!, hasTechniqueViolation);
          _recordPhaseObservation(
            phase: MovementPhase.peak,
            primaryMetric: angle,
            formMetric: compatibilityFormMetric,
            hasTechniqueViolation: hasTechniqueViolation,
          );
        }
        if (angle < _currentRepMinAngle) _currentRepMinAngle = angle;

        final ascentConfirmedAt = _confirmTransition(
          transition: _PhaseTransition.startAscending,
          condition: angle > _peakExitThreshold,
          now: now,
        );
        if (ascentConfirmedAt != null) {
          confirmedTransition = _PhaseTransition.startAscending.confirmedAt(
            ascentConfirmedAt,
          );
          observedRepPhases.add(RangeRepPhase.ascending);
          state = MovementPhase.ascending;
          _ascentStartTime = ascentConfirmedAt;
          if (tracksCompatibilityTechnique) {
            _completePhaseTelemetry(
              phase: MovementPhase.peak,
              phaseEndedAt: ascentConfirmedAt,
            );
            _beginPhaseTelemetry(
              phase: MovementPhase.ascending,
              phaseStartedAt: ascentConfirmedAt,
              primaryMetric: angle,
              formMetric: compatibilityFormMetric!,
              hasTechniqueViolation: hasTechniqueViolation,
            );
            _setFeedback(RangeRepFeedbackCode.ascend);
          }
        }
        break;

      case MovementPhase.ascending:
        observedRepPhases.add(RangeRepPhase.ascending);
        if (tracksCompatibilityTechnique) {
          _trackRepForm(compatibilityFormMetric!, hasTechniqueViolation);
          _recordPhaseObservation(
            phase: MovementPhase.ascending,
            primaryMetric: angle,
            formMetric: compatibilityFormMetric,
            hasTechniqueViolation: hasTechniqueViolation,
          );
        }
        final repCompleteAt = _confirmTransition(
          transition: _PhaseTransition.completeRep,
          condition: angle > _neutralReturnThreshold,
          now: now,
        );
        if (repCompleteAt != null) {
          confirmedTransition = _PhaseTransition.completeRep.confirmedAt(
            repCompleteAt,
          );
          if (_ascentStartTime != null) {
            lastAscentTime = repCompleteAt.difference(_ascentStartTime!);
          }
          if (tracksCompatibilityTechnique) {
            _completePhaseTelemetry(
              phase: MovementPhase.ascending,
              phaseEndedAt: repCompleteAt,
            );
          }
          final completionFacts = _finishRep(
            tracksCompatibilityTechnique: tracksCompatibilityTechnique,
            calculateCompatibilityScore: calculateCompatibilityScore,
          );
          completedRepDetectionData = completionFacts.detectionData;
          completedRepCoreData = completionFacts.compatibilityCoreData;
          state = MovementPhase.neutral;
          if (tracksCompatibilityTechnique) {
            _captureLastCompletedPhaseQualityTelemetry(repCompleteAt);
          }
        }
        break;
    }

    return _RangeRepLifecycleFacts(
      repStarted: repStarted,
      repAborted: repAborted,
      completedRepDetectionData: completedRepDetectionData,
      completedRepCoreData: completedRepCoreData,
      confirmedTransition: confirmedTransition,
      observedRepPhases: observedRepPhases,
    );
  }

  _RangeRepCompletionFacts _finishRep({
    required bool tracksCompatibilityTechnique,
    required bool calculateCompatibilityScore,
  }) {
    repCount++;
    _lastRepRom = _currentRepMinAngle;
    final completedPhaseSequence =
        _descentStartTime != null &&
        _peakStartTime != null &&
        _ascentStartTime != null;
    final detectionData = RangeRepCompletedRepDetectionData(
      repIndex: repCount,
      minAngle: _lastRepRom,
      descentDuration: lastDescentTime,
      ascentDuration: lastAscentTime,
      completedPhaseSequence: completedPhaseSequence,
    );
    if (!tracksCompatibilityTechnique) {
      return _RangeRepCompletionFacts(detectionData: detectionData);
    }

    final completedPhaseQualityTelemetry = _completedPhaseQualityTelemetry(
      _now(),
    );
    final descendingPhaseAssessment = _assessPhaseQuality(
      phase: MovementPhase.descending,
      phaseQuality: completedPhaseQualityTelemetry.descendingPhaseQuality,
      isActivePhase: false,
    );
    final peakPhaseAssessment = _assessPhaseQuality(
      phase: MovementPhase.peak,
      phaseQuality: completedPhaseQualityTelemetry.peakPhaseQuality,
      isActivePhase: false,
    );
    final ascendingPhaseAssessment = _assessPhaseQuality(
      phase: MovementPhase.ascending,
      phaseQuality: completedPhaseQualityTelemetry.ascendingPhaseQuality,
      isActivePhase: false,
    );
    final phaseFeedbackCodeCandidate = _phaseFeedbackCodeCandidate(
      descendingPhaseAssessment: descendingPhaseAssessment,
      peakPhaseAssessment: peakPhaseAssessment,
      ascendingPhaseAssessment: ascendingPhaseAssessment,
    );
    final completedRepCoreData = RangeRepCompletedRepCoreData(
      repIndex: detectionData.repIndex,
      minAngle: detectionData.minAngle,
      worstFormMetric: _currentRepWorstBackAngle,
      descentDuration: detectionData.descentDuration,
      ascentDuration: detectionData.ascentDuration,
      hadFormViolation: _currentRepHadFormViolation,
      completedPhaseSequence: detectionData.completedPhaseSequence,
    );
    lastCompletedRepCoreData = completedRepCoreData;

    if (calculateCompatibilityScore) {
      _pendingCompletedRepCoreData = completedRepCoreData;
      _calculateCompatibilityScore(
        completedRepCoreData: completedRepCoreData,
        descendingPhaseAssessment: descendingPhaseAssessment,
        ascendingPhaseAssessment: ascendingPhaseAssessment,
      );
    }

    _setFeedback(
      phaseFeedbackCodeCandidate ?? RangeRepFeedbackCode.repCompleted,
    );
    return _RangeRepCompletionFacts(
      detectionData: detectionData,
      compatibilityCoreData: completedRepCoreData,
    );
  }

  void _calculateCompatibilityScore({
    required RangeRepCompletedRepCoreData completedRepCoreData,
    required RangeRepPhaseQualityAssessment descendingPhaseAssessment,
    required RangeRepPhaseQualityAssessment ascendingPhaseAssessment,
  }) {
    final romScore = _scorer.calculateRomScore(
      minAngle: completedRepCoreData.minAngle,
      targetMinAngle: config.targetMinAngle,
    );
    final descentSeconds =
        completedRepCoreData.descentDuration.inMilliseconds / 1000.0;
    final descentScore = _scorer.calculateTempoScore(
      actualSeconds: descentSeconds,
      idealSeconds: config.idealDescentSeconds,
      tempoPenaltyPerSecond: config.tempoPenaltyPerSecond,
    );
    final ascentSeconds =
        completedRepCoreData.ascentDuration.inMilliseconds / 1000.0;
    final ascentScore = _scorer.calculateTempoScore(
      actualSeconds: ascentSeconds,
      idealSeconds: config.idealAscentSeconds,
      tempoPenaltyPerSecond: config.tempoPenaltyPerSecond,
    );
    final tempoScore = (descentScore + ascentScore) / 2;
    final depthScore = romScore;
    final descentControlScore = descentScore;
    final ascentControlScore = ascentScore;
    final scoreWeights = config.rangeRepScoreWeights;
    final weightedBaseScore = scoreWeights == null
        ? null
        : _scorer.calculateWeightedBaseScore(
            depthScore: depthScore,
            descentControlScore: descentControlScore,
            ascentControlScore: ascentControlScore,
            depthWeight: scoreWeights.depthWeight ?? 1.0,
            descentControlWeight: scoreWeights.descentControlWeight ?? 1.0,
            ascentControlWeight: scoreWeights.ascentControlWeight ?? 1.0,
          );
    final phaseQualityPenalty = _scorer.calculatePhaseQualityPenalty(
      descendingPhaseFlagged:
          descendingPhaseAssessment.status ==
          RangeRepPhaseQualityStatus.flagged,
      ascendingPhaseFlagged:
          ascendingPhaseAssessment.status == RangeRepPhaseQualityStatus.flagged,
    );
    final baseScore = _scorer.calculateBaseScore(
      romScore: romScore,
      tempoScore: tempoScore,
      weightedBaseScore: weightedBaseScore,
      hadFormViolation: completedRepCoreData.hadFormViolation,
    );
    final phaseAdjustedScore = _scorer.calculatePhaseAdjustedScore(
      baseScore: baseScore,
      phaseQualityPenalty: phaseQualityPenalty,
    );
    final finalScore = _scorer.calculateFinalScore(
      baseScore: baseScore,
      phaseAdjustedScore: phaseAdjustedScore,
    );

    lastRepScore = finalScore;
    lastRepScoreBreakdown = RepScoreBreakdown(
      minAngle: completedRepCoreData.minAngle,
      romScore: romScore,
      descentSeconds: descentSeconds,
      descentScore: descentScore,
      ascentSeconds: ascentSeconds,
      ascentScore: ascentScore,
      worstBackAngle: completedRepCoreData.worstFormMetric,
      hadFormViolation: completedRepCoreData.hadFormViolation,
      runtimeBaseScore: baseScore,
      finalScore: finalScore,
      depthScore: depthScore,
      descentControlScore: descentControlScore,
      ascentControlScore: ascentControlScore,
      weightedBaseScore: weightedBaseScore,
      phaseQualityPenalty: phaseQualityPenalty,
      phaseAdjustedScore: phaseAdjustedScore,
    );
  }

  RangeRepPhaseQualityTelemetry _phaseQualityTelemetry(DateTime now) {
    return RangeRepPhaseQualityTelemetry(
      descendingPhaseQuality: _descendingPhaseQuality.snapshot(
        now: now,
        isActive: state == MovementPhase.descending,
      ),
      peakPhaseQuality: _peakPhaseQuality.snapshot(
        now: now,
        isActive: state == MovementPhase.peak,
      ),
      ascendingPhaseQuality: _ascendingPhaseQuality.snapshot(
        now: now,
        isActive: state == MovementPhase.ascending,
      ),
    );
  }

  RangeRepPhaseQualityTelemetry _completedPhaseQualityTelemetry(
    DateTime capturedAt,
  ) {
    return RangeRepPhaseQualityTelemetry(
      descendingPhaseQuality: _descendingPhaseQuality.snapshot(
        now: capturedAt,
        isActive: false,
      ),
      peakPhaseQuality: _peakPhaseQuality.snapshot(
        now: capturedAt,
        isActive: false,
      ),
      ascendingPhaseQuality: _ascendingPhaseQuality.snapshot(
        now: capturedAt,
        isActive: false,
      ),
    );
  }

  RangeRepPhaseQualityAssessment _assessPhaseQuality({
    required MovementPhase phase,
    required RangeRepPhaseQualitySnapshot phaseQuality,
    required bool isActivePhase,
  }) {
    final rangeRepPhase = switch (phase) {
      MovementPhase.descending => RangeRepPhase.descending,
      MovementPhase.peak => RangeRepPhase.peak,
      MovementPhase.ascending => RangeRepPhase.ascending,
      MovementPhase.neutral => throw ArgumentError.value(
        phase,
        'phase',
        'Neutral has no phase-quality assessment.',
      ),
    };
    return _phaseQualityPolicy.assess(
      phase: rangeRepPhase,
      phaseQuality: phaseQuality,
      isActivePhase: isActivePhase,
      config: config.rangeRepPhaseQuality,
    );
  }

  RangeRepFeedbackCode? _phaseFeedbackCodeCandidate({
    required RangeRepPhaseQualityAssessment descendingPhaseAssessment,
    required RangeRepPhaseQualityAssessment peakPhaseAssessment,
    required RangeRepPhaseQualityAssessment ascendingPhaseAssessment,
  }) {
    return _phaseQualityPolicy.feedbackCandidate(
      descending: descendingPhaseAssessment,
      peak: peakPhaseAssessment,
      ascending: ascendingPhaseAssessment,
    );
  }

  String _feedbackMessageForCode(RangeRepFeedbackCode code) {
    switch (code) {
      case RangeRepFeedbackCode.awaitNeutral:
        return 'Baslangic pozisyonuna gec.';
      case RangeRepFeedbackCode.ready:
        return 'Hazir!';
      case RangeRepFeedbackCode.waitForBody:
        return 'Vucut Bekleniyor...';
      case RangeRepFeedbackCode.bodyNotVisible:
        return 'Vucut net gorunmuyor.';
      case RangeRepFeedbackCode.descend:
        return 'Asagi in...';
      case RangeRepFeedbackCode.ascend:
        return 'Yukari...';
      case RangeRepFeedbackCode.repCompleted:
        return 'Basarili!';
      case RangeRepFeedbackCode.repIncomplete:
        return 'Hareketi tamamlamadin.';
      case RangeRepFeedbackCode.keepBodyUpright:
        return 'Sirtini Dik Tut!';
      case RangeRepFeedbackCode.controlDescent:
        return 'Inisi kontrollu yap.';
      case RangeRepFeedbackCode.controlAscent:
        return 'Yukselisi kontrollu yap.';
      case RangeRepFeedbackCode.stabilizeTransition:
        return 'Dipte gecisi sabitle.';
      case RangeRepFeedbackCode.maintainForm:
        return 'Formunu koru.';
    }
  }

  void _setFeedback(RangeRepFeedbackCode code) {
    _feedbackCode = code;
    feedback = _feedbackMessageForCode(code);
  }

  void _captureLastCompletedPhaseQualityTelemetry(DateTime capturedAt) {
    _lastCompletedPhaseQualityTelemetry = _completedPhaseQualityTelemetry(
      capturedAt,
    );
  }

  void _beginPhaseTelemetry({
    required MovementPhase phase,
    required DateTime phaseStartedAt,
    required double primaryMetric,
    required double formMetric,
    required bool hasTechniqueViolation,
  }) {
    _phaseQualityFor(phase).start(
      startedAt: phaseStartedAt,
      primaryMetric: primaryMetric,
      formMetric: formMetric,
      hadFormViolation: hasTechniqueViolation,
    );
  }

  void _recordPhaseObservation({
    required MovementPhase phase,
    required double primaryMetric,
    required double formMetric,
    required bool hasTechniqueViolation,
  }) {
    _phaseQualityFor(phase).record(
      primaryMetric: primaryMetric,
      formMetric: formMetric,
      hadFormViolation: hasTechniqueViolation,
    );
  }

  void _completePhaseTelemetry({
    required MovementPhase phase,
    required DateTime phaseEndedAt,
  }) {
    _phaseQualityFor(phase).complete(phaseEndedAt);
  }

  _MutableRangeRepPhaseQuality _phaseQualityFor(MovementPhase phase) {
    switch (phase) {
      case MovementPhase.neutral:
        throw ArgumentError.value(
          phase,
          'phase',
          'Neutral has no phase telemetry.',
        );
      case MovementPhase.descending:
        return _descendingPhaseQuality;
      case MovementPhase.peak:
        return _peakPhaseQuality;
      case MovementPhase.ascending:
        return _ascendingPhaseQuality;
    }
  }

  void _resetPhaseQualityTelemetry() {
    _descendingPhaseQuality.reset();
    _peakPhaseQuality.reset();
    _ascendingPhaseQuality.reset();
  }

  void _startDetectionRepMetrics(double primaryMetric) {
    _currentRepMinAngle = primaryMetric;
  }

  void _startCompatibilityRepMetrics(
    double formMetric, {
    required bool hasTechniqueViolation,
    required DateTime phaseStartedAt,
    required double primaryMetric,
  }) {
    _currentRepWorstBackAngle = formMetric;
    _currentRepHadFormViolation = hasTechniqueViolation;
    _resetPhaseQualityTelemetry();
    _beginPhaseTelemetry(
      phase: MovementPhase.descending,
      phaseStartedAt: phaseStartedAt,
      primaryMetric: primaryMetric,
      formMetric: formMetric,
      hasTechniqueViolation: hasTechniqueViolation,
    );
  }

  void _trackRepForm(double backAngle, bool hasTechniqueViolation) {
    if (backAngle < _currentRepWorstBackAngle) {
      _currentRepWorstBackAngle = backAngle;
    }
    if (hasTechniqueViolation) {
      _currentRepHadFormViolation = true;
    }
  }

  void _resetCurrentRepMetrics() {
    _resetDetectionRepMetrics();
    _resetCompatibilityRepMetrics();
  }

  void _resetDetectionRepMetrics() {
    _currentRepMinAngle = 180.0;
    _clearPendingTransition();
  }

  void _resetCompatibilityRepMetrics() {
    _currentRepWorstBackAngle = 180.0;
    _currentRepHadFormViolation = false;
    _resetPhaseQualityTelemetry();
  }

  void _checkForm(bool hasTechniqueViolation) {
    // Live feedback uses the current frame; final scoring uses rep-level history.
    if (hasTechniqueViolation) {
      isFormBad = true;
      _setFeedback(RangeRepFeedbackCode.keepBodyUpright);
    } else {
      isFormBad = false;
    }
  }

  double get _descentEntryThreshold =>
      config.thresholdActive - _descentEntryMargin;

  double get _peakEntryThreshold => config.thresholdPeak - _peakEntryMargin;

  double get _peakExitThreshold => config.thresholdPeak + _peakExitMargin;

  double get _neutralReturnThreshold => config.thresholdNeutral;

  String get _phaseGateStatus {
    if (_pendingTransition == null || _pendingTransitionStartedAt == null) {
      return _isArmed ? 'stable ${state.name}' : 'stable awaiting neutral';
    }

    final elapsedMs = _now()
        .difference(_pendingTransitionStartedAt!)
        .inMilliseconds;
    final requiredMs = _pendingTransition!.confirmationDuration.inMilliseconds;

    return 'confirming ${_pendingTransition!.debugLabel} '
        '(${elapsedMs}ms/${requiredMs}ms)';
  }

  DateTime? _confirmTransition({
    required _PhaseTransition transition,
    required bool condition,
    required DateTime now,
  }) {
    if (!condition) {
      if (_pendingTransition == transition) {
        _clearPendingTransition();
      }
      return null;
    }

    if (_pendingTransition != transition ||
        _pendingTransitionStartedAt == null) {
      _pendingTransition = transition;
      _pendingTransitionStartedAt = now;
      return null;
    }

    final startedAt = _pendingTransitionStartedAt!;
    if (now.difference(startedAt) < transition.confirmationDuration) {
      return null;
    }

    _lastConfirmedTransitionLabel = transition.debugLabel;
    _clearPendingTransition();
    return startedAt;
  }

  void _clearPendingTransition() {
    _pendingTransition = null;
    _pendingTransitionStartedAt = null;
  }

  @override
  void beginBriefVisibilityGap() {
    if (_briefVisibilityGapWindow.isActive) {
      return;
    }

    _briefVisibilityGapWindow.begin(_now());
    _briefVisibilityGapFrozenPhase = state;
    _briefVisibilityGapWasArmed = _isArmed;
    _clearPendingTransition();
  }

  @override
  VisibilityGapResumeResult resumeAfterBriefVisibilityGap({
    required double primaryMetric,
  }) {
    if (!_briefVisibilityGapWindow.isActive) {
      return const VisibilityGapResumeResult(
        disposition: VisibilityGapResumeDisposition.noGap,
      );
    }

    final frozenPhase = _briefVisibilityGapFrozenPhase ?? state;
    final isCompatible = _isFrameCompatibleWithFrozenPhase(
      primaryMetric,
      frozenPhase: frozenPhase,
      wasArmed: _briefVisibilityGapWasArmed,
    );
    if (!isCompatible) {
      _clearBriefVisibilityGap();
      return const VisibilityGapResumeResult(
        disposition: VisibilityGapResumeDisposition.incompatible,
        reason: 'phase incompatible recovery',
      );
    }

    final gapDuration = _briefVisibilityGapWindow.consume(_now())!;
    _shiftActivePhaseTiming(gapDuration);
    _briefVisibilityGapFrozenPhase = null;
    _briefVisibilityGapWasArmed = false;

    return VisibilityGapResumeResult(
      disposition: VisibilityGapResumeDisposition.compatible,
      appliedGapDuration: gapDuration,
    );
  }

  @override
  void clearActiveRepContext({String? reason}) {
    _disarm();
  }

  @override
  void interrupt({String? reason}) {
    clearActiveRepContext(reason: reason);
  }

  @override
  void reset() {
    repCount = 0;
    lastRepScore = 0;
    lastRepScoreBreakdown = null;
    lastCompletedRepCoreData = null;
    _pendingCompletedRepCoreData = null;
    _lastRepRom = 180;
    lastDescentTime = Duration.zero;
    lastAscentTime = Duration.zero;
    _descentStartTime = null;
    _peakStartTime = null;
    _ascentStartTime = null;
    _briefVisibilityGapWindow.reset();
    _briefVisibilityGapFrozenPhase = null;
    _briefVisibilityGapWasArmed = false;
    _lastCompletedPhaseQualityTelemetry = null;
    _disarm();
  }

  void _disarm() {
    _isArmed = false;
    state = MovementPhase.neutral;
    isFormBad = false;
    _setFeedback(RangeRepFeedbackCode.awaitNeutral);
    _descentStartTime = null;
    _peakStartTime = null;
    _ascentStartTime = null;
    _clearBriefVisibilityGap();
    _lastConfirmedTransitionLabel = null;
    _resetCurrentRepMetrics();
  }

  void _clearBriefVisibilityGap() {
    _briefVisibilityGapWindow.reset();
    _briefVisibilityGapFrozenPhase = null;
    _briefVisibilityGapWasArmed = false;
  }

  bool _isFrameCompatibleWithFrozenPhase(
    double primaryMetric, {
    required MovementPhase frozenPhase,
    required bool wasArmed,
  }) {
    if (!wasArmed) {
      return primaryMetric > _neutralReturnThreshold;
    }

    switch (frozenPhase) {
      case MovementPhase.neutral:
        return primaryMetric > _neutralReturnThreshold;
      case MovementPhase.descending:
        return primaryMetric >= _peakEntryThreshold &&
            primaryMetric < _neutralReturnThreshold;
      case MovementPhase.peak:
        return primaryMetric <= _peakExitThreshold;
      case MovementPhase.ascending:
        return primaryMetric > _peakExitThreshold &&
            primaryMetric < _neutralReturnThreshold;
    }
  }

  void _shiftActivePhaseTiming(Duration gapDuration) {
    if (gapDuration <= Duration.zero) {
      return;
    }

    switch (state) {
      case MovementPhase.neutral:
        break;
      case MovementPhase.descending:
        if (_descentStartTime != null) {
          _descentStartTime = _descentStartTime!.add(gapDuration);
        }
        _descendingPhaseQuality.shiftStartedAt(gapDuration);
        break;
      case MovementPhase.peak:
        if (_peakStartTime != null) {
          _peakStartTime = _peakStartTime!.add(gapDuration);
        }
        _peakPhaseQuality.shiftStartedAt(gapDuration);
        break;
      case MovementPhase.ascending:
        if (_ascentStartTime != null) {
          _ascentStartTime = _ascentStartTime!.add(gapDuration);
        }
        _ascendingPhaseQuality.shiftStartedAt(gapDuration);
        break;
    }
  }
}
