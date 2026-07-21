import 'analysis_visibility_gap_window.dart';
import 'feedback_arbitration_engine.dart';
import 'generic_rep_engine.dart';
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
import 'tempo_engine.dart';

enum MovementPhase { neutral, descending, peak, ascending }

extension _GenericRepTransitionX on GenericRepTransitionType {
  RangeRepConfirmedTransition confirmedAt(DateTime effectiveAt) {
    final type = switch (this) {
      GenericRepTransitionType.acquireNeutral =>
        RangeRepConfirmedTransitionType.acquireNeutral,
      GenericRepTransitionType.startTowardPeak =>
        RangeRepConfirmedTransitionType.startDescending,
      GenericRepTransitionType.reachPeak =>
        RangeRepConfirmedTransitionType.reachPeak,
      GenericRepTransitionType.startReturning =>
        RangeRepConfirmedTransitionType.startAscending,
      GenericRepTransitionType.abortToNeutral =>
        RangeRepConfirmedTransitionType.abortToNeutral,
      GenericRepTransitionType.completeRep =>
        RangeRepConfirmedTransitionType.completeRep,
    };
    return RangeRepConfirmedTransition(type: type, effectiveAt: effectiveAt);
  }

  String get legacyDebugLabel {
    return switch (this) {
      GenericRepTransitionType.acquireNeutral =>
        rangeRepAwaitNeutralPendingTransitionLabel,
      GenericRepTransitionType.startTowardPeak => 'neutral -> descending',
      GenericRepTransitionType.reachPeak => 'descending -> peak',
      GenericRepTransitionType.startReturning => 'peak -> ascending',
      GenericRepTransitionType.abortToNeutral => 'descending -> neutral',
      GenericRepTransitionType.completeRep => 'ascending -> neutral',
    };
  }
}

class _RangeRepLifecycleFacts {
  _RangeRepLifecycleFacts({
    required this.repStarted,
    required this.repAborted,
    required this.completedRepDetectionData,
    required this.completedRepCoreData,
    required this.confirmedTransition,
    required List<RangeRepPhase> observedRepPhases,
    this.completedTempo,
  }) : observedRepPhases = List<RangeRepPhase>.unmodifiable(observedRepPhases);

  final bool repStarted;
  final bool repAborted;
  final RangeRepCompletedRepDetectionData? completedRepDetectionData;
  final RangeRepCompletedRepCoreData? completedRepCoreData;
  final RangeRepConfirmedTransition? confirmedTransition;
  final List<RangeRepPhase> observedRepPhases;
  final TempoRepResult? completedTempo;
}

class _RangeRepCompletionFacts {
  const _RangeRepCompletionFacts({
    required this.detectionData,
    this.compatibilityCoreData,
  });

  final RangeRepCompletedRepDetectionData detectionData;
  final RangeRepCompletedRepCoreData? compatibilityCoreData;
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
class RangeRepEngine implements RangeRepAnalysisEngine, TempoMetricsSource {
  final ExerciseConfig config;
  final RangeRepPrimaryMetricDirection primaryMetricDirection;
  final DateTime Function() _now;
  final LegacyRangeRepScorer _scorer = const LegacyRangeRepScorer();
  final LegacyRangeRepTechniqueEvaluator _techniqueEvaluator =
      const LegacyRangeRepTechniqueEvaluator();
  final LegacyRangeRepPhaseQualityPolicy _phaseQualityPolicy =
      const LegacyRangeRepPhaseQualityPolicy();
  final FeedbackArbitrationEngine _feedbackArbitrationEngine =
      const FeedbackArbitrationEngine();

  MovementPhase state = MovementPhase.neutral;
  bool _isArmed = false;
  @override
  int repCount = 0;
  bool isFormBad = false;

  // Compatibility ROM value for the most recently completed repetition.
  double _lastRepRom = 180.0;
  double _currentRepStartAngle = 180.0;
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
  double _currentRepMaxAngle = 0.0;
  double _currentRepWorstBackAngle = 180.0;
  bool _currentRepHadFormViolation = false;
  late final GenericRepEngine _genericRepEngine;
  late final TempoEngine _tempoEngine;
  String? _lastConfirmedTransitionLabel;
  final _MutableRangeRepPhaseQuality _descendingPhaseQuality =
      _MutableRangeRepPhaseQuality();
  final _MutableRangeRepPhaseQuality _peakPhaseQuality =
      _MutableRangeRepPhaseQuality();
  final _MutableRangeRepPhaseQuality _ascendingPhaseQuality =
      _MutableRangeRepPhaseQuality();
  RangeRepPhaseQualityTelemetry? _lastCompletedPhaseQualityTelemetry;

  RangeRepEngine({
    required this.config,
    this.primaryMetricDirection =
        RangeRepPrimaryMetricDirection.decreasingToPeak,
    RangeRepTowardPeakMuscleAction towardPeakMuscleAction =
        RangeRepTowardPeakMuscleAction.eccentric,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now {
    _genericRepEngine = GenericRepEngine(
      config: GenericRepEngineConfig(
        neutralThreshold: config.thresholdNeutral,
        activeThreshold: config.thresholdActive,
        peakThreshold: config.thresholdPeak,
        direction: switch (primaryMetricDirection) {
          RangeRepPrimaryMetricDirection.decreasingToPeak =>
            GenericRepMetricDirection.decreasingToPeak,
          RangeRepPrimaryMetricDirection.increasingToPeak =>
            GenericRepMetricDirection.increasingToPeak,
        },
      ),
      now: _now,
    );
    _tempoEngine = TempoEngine(
      towardPeakAction: switch (towardPeakMuscleAction) {
        RangeRepTowardPeakMuscleAction.eccentric =>
          TempoTowardPeakAction.eccentric,
        RangeRepTowardPeakMuscleAction.concentric =>
          TempoTowardPeakAction.concentric,
      },
    );
    _disarm();
  }

  @override
  TempoRepResult? get lastCompletedTempo => _tempoEngine.lastCompletedRep;

  @override
  TempoSessionSummary get tempoSessionSummary => _tempoEngine.sessionSummary;

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
      hasPendingTransition: _genericRepEngine.pendingTransition != null,
      pendingTransitionLabel:
          _genericRepEngine.pendingTransition?.legacyDebugLabel,
      lastConfirmedTransitionLabel: _lastConfirmedTransitionLabel,
    );
  }

  RangeRepDiagnosticsSnapshot get diagnosticsSnapshot {
    final now = _now();
    final phaseQualityTelemetry =
        state == MovementPhase.neutral &&
            _genericRepEngine.pendingTransition == null
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
      hasPendingTransition: _genericRepEngine.pendingTransition != null,
      pendingTransitionLabel:
          _genericRepEngine.pendingTransition?.legacyDebugLabel,
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
    _arbitrateLiveFeedback(
      hasTechniqueViolation:
          tracksCompatibilityTechnique &&
          wasArmedAtFrameStart &&
          hasTechniqueViolation,
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
      completedTempo: lifecycleFacts.completedTempo,
    );
  }

  _RangeRepLifecycleFacts _processState(
    double angle, {
    required double? compatibilityFormMetric,
    required bool hasTechniqueViolation,
    required bool tracksCompatibilityTechnique,
    required bool calculateCompatibilityScore,
  }) {
    final genericResult = _genericRepEngine.update(primaryMetric: angle);
    final completedTempo = _tempoEngine.process(genericResult);
    final transition = genericResult.confirmedTransition;
    final stateBefore = _movementPhaseFor(genericResult.phaseBeforeUpdate);

    _isArmed = genericResult.isArmedAfterUpdate;
    state = _movementPhaseFor(genericResult.phaseAfterUpdate);
    repCount = _genericRepEngine.repCount;

    final observedRepPhases = <RangeRepPhase>[];
    if (genericResult.wasArmedAtFrameStart) {
      switch (stateBefore) {
        case MovementPhase.neutral:
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
          _recordPrimaryExtrema(angle);
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
          _recordPrimaryExtrema(angle);
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
          _recordPrimaryExtrema(angle);
          break;
      }
    }

    var repStarted = genericResult.repStarted;
    var repAborted = genericResult.repAborted;
    RangeRepCompletedRepDetectionData? completedRepDetectionData;
    RangeRepCompletedRepCoreData? completedRepCoreData;
    RangeRepConfirmedTransition? confirmedTransition;

    if (transition != null) {
      _lastConfirmedTransitionLabel = transition.type.legacyDebugLabel;
      confirmedTransition = transition.type.confirmedAt(transition.effectiveAt);

      switch (transition.type) {
        case GenericRepTransitionType.acquireNeutral:
          if (tracksCompatibilityTechnique) {
            _setFeedback(RangeRepFeedbackCode.ready);
          }
          break;

        case GenericRepTransitionType.startTowardPeak:
          observedRepPhases.add(RangeRepPhase.descending);
          _descentStartTime = transition.effectiveAt;
          _startDetectionRepMetrics(angle);
          if (tracksCompatibilityTechnique) {
            _startCompatibilityRepMetrics(
              compatibilityFormMetric!,
              hasTechniqueViolation: hasTechniqueViolation,
              phaseStartedAt: transition.effectiveAt,
              primaryMetric: angle,
            );
            _setFeedback(RangeRepFeedbackCode.descend);
          }
          break;

        case GenericRepTransitionType.reachPeak:
          observedRepPhases.add(RangeRepPhase.peak);
          _peakStartTime = transition.effectiveAt;
          if (_descentStartTime != null) {
            lastDescentTime = _peakStartTime!.difference(_descentStartTime!);
          }
          if (tracksCompatibilityTechnique) {
            _completePhaseTelemetry(
              phase: MovementPhase.descending,
              phaseEndedAt: transition.effectiveAt,
            );
            _beginPhaseTelemetry(
              phase: MovementPhase.peak,
              phaseStartedAt: transition.effectiveAt,
              primaryMetric: angle,
              formMetric: compatibilityFormMetric!,
              hasTechniqueViolation: hasTechniqueViolation,
            );
            _setFeedback(RangeRepFeedbackCode.ascend);
          }
          break;

        case GenericRepTransitionType.startReturning:
          observedRepPhases.add(RangeRepPhase.ascending);
          _ascentStartTime = transition.effectiveAt;
          if (tracksCompatibilityTechnique) {
            _completePhaseTelemetry(
              phase: MovementPhase.peak,
              phaseEndedAt: transition.effectiveAt,
            );
            _beginPhaseTelemetry(
              phase: MovementPhase.ascending,
              phaseStartedAt: transition.effectiveAt,
              primaryMetric: angle,
              formMetric: compatibilityFormMetric!,
              hasTechniqueViolation: hasTechniqueViolation,
            );
            _setFeedback(RangeRepFeedbackCode.ascend);
          }
          break;

        case GenericRepTransitionType.abortToNeutral:
          repStarted = false;
          repAborted = true;
          _resetDetectionRepMetrics();
          if (tracksCompatibilityTechnique) {
            _resetCompatibilityRepMetrics();
            _setFeedback(RangeRepFeedbackCode.repIncomplete);
          }
          break;

        case GenericRepTransitionType.completeRep:
          if (_ascentStartTime != null) {
            lastAscentTime = transition.effectiveAt.difference(
              _ascentStartTime!,
            );
          }
          if (tracksCompatibilityTechnique) {
            _completePhaseTelemetry(
              phase: MovementPhase.ascending,
              phaseEndedAt: transition.effectiveAt,
            );
          }

          if (genericResult.completedRep != null) {
            final completionFacts = _finishRep(
              tracksCompatibilityTechnique: tracksCompatibilityTechnique,
              calculateCompatibilityScore: calculateCompatibilityScore,
            );
            completedRepDetectionData = completionFacts.detectionData;
            completedRepCoreData = completionFacts.compatibilityCoreData;
            if (tracksCompatibilityTechnique) {
              _captureLastCompletedPhaseQualityTelemetry(
                transition.effectiveAt,
              );
            }
          } else {
            repAborted = true;
            _resetCurrentRepMetrics();
            if (tracksCompatibilityTechnique) {
              _setFeedback(RangeRepFeedbackCode.repIncomplete);
            }
          }
          break;
      }
    }

    return _RangeRepLifecycleFacts(
      repStarted: repStarted,
      repAborted: repAborted,
      completedRepDetectionData: completedRepDetectionData,
      completedRepCoreData: completedRepCoreData,
      confirmedTransition: confirmedTransition,
      observedRepPhases: observedRepPhases,
      completedTempo: completedTempo,
    );
  }

  MovementPhase _movementPhaseFor(GenericRepPhase phase) {
    return switch (phase) {
      GenericRepPhase.neutral => MovementPhase.neutral,
      GenericRepPhase.towardPeak => MovementPhase.descending,
      GenericRepPhase.peak => MovementPhase.peak,
      GenericRepPhase.returning => MovementPhase.ascending,
    };
  }

  _RangeRepCompletionFacts _finishRep({
    required bool tracksCompatibilityTechnique,
    required bool calculateCompatibilityScore,
  }) {
    _lastRepRom = _currentRepMinAngle;
    final completedPhaseSequence =
        _descentStartTime != null &&
        _peakStartTime != null &&
        _ascentStartTime != null;
    final peakMetric = _peakMetricForCurrentRep;
    final primaryRom = (peakMetric - _currentRepStartAngle)
        .abs()
        .clamp(0.0, 180.0)
        .toDouble();
    final detectionData = RangeRepCompletedRepDetectionData(
      repIndex: repCount,
      minAngle: _lastRepRom,
      descentDuration: lastDescentTime,
      ascentDuration: lastAscentTime,
      completedPhaseSequence: completedPhaseSequence,
      startAngle: _currentRepStartAngle,
      primaryRom: primaryRom,
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
      startAngle: detectionData.startAngle,
      primaryRom: detectionData.primaryRom,
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
    final romScore = switch (primaryMetricDirection) {
      RangeRepPrimaryMetricDirection.decreasingToPeak =>
        _scorer.calculateRomScore(
          minAngle: completedRepCoreData.minAngle,
          targetMinAngle: config.targetMinAngle,
        ),
      RangeRepPrimaryMetricDirection.increasingToPeak =>
        _scorer
            .calculateSaturatingRomScore(
              achievedRom: completedRepCoreData.primaryRom ?? 0.0,
              minimumAcceptableRom: 0.0,
              targetRom:
                  ((config.targetMaxAngle ?? config.thresholdPeak) -
                          (completedRepCoreData.startAngle ??
                              config.thresholdNeutral))
                      .clamp(0.0, 180.0)
                      .toDouble(),
            )
            .score,
    };
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
    _currentRepStartAngle = primaryMetric;
    _currentRepMinAngle = primaryMetric;
    _currentRepMaxAngle = primaryMetric;
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
    _currentRepStartAngle =
        primaryMetricDirection ==
            RangeRepPrimaryMetricDirection.decreasingToPeak
        ? 180.0
        : 0.0;
    _currentRepMinAngle = 180.0;
    _currentRepMaxAngle = 0.0;
  }

  void _resetCompatibilityRepMetrics() {
    _currentRepWorstBackAngle = 180.0;
    _currentRepHadFormViolation = false;
    _resetPhaseQualityTelemetry();
  }

  void _checkForm(bool hasTechniqueViolation) {
    // Live feedback uses the current frame; final scoring uses rep-level history.
    // User-facing selection happens after lifecycle processing so movement and
    // corrective candidates can be arbitrated together instead of whichever
    // setter happened to run last winning implicitly.
    isFormBad = hasTechniqueViolation;
  }

  void _arbitrateLiveFeedback({required bool hasTechniqueViolation}) {
    final currentFeedbackCode = _feedbackCode;
    final candidates = <FeedbackCandidate<RangeRepFeedbackCode>>[
      if (currentFeedbackCode != null)
        FeedbackCandidate<RangeRepFeedbackCode>(
          id: 'range_rep_current_${currentFeedbackCode.code}',
          value: currentFeedbackCode,
          priority: _priorityForRangeRepFeedback(currentFeedbackCode),
        ),
      if (hasTechniqueViolation)
        const FeedbackCandidate<RangeRepFeedbackCode>(
          id: 'range_rep_live_form_correction',
          value: RangeRepFeedbackCode.legacyFormThresholdViolation,
          priority: FeedbackPriority.corrective,
        ),
    ];
    final selected = _feedbackArbitrationEngine
        .arbitrate<RangeRepFeedbackCode>(candidates: candidates)
        .selectedValue;
    if (selected != null) {
      _setFeedback(selected);
    }
  }

  FeedbackPriority _priorityForRangeRepFeedback(RangeRepFeedbackCode code) {
    return switch (code) {
      RangeRepFeedbackCode.awaitNeutral ||
      RangeRepFeedbackCode.ready => FeedbackPriority.status,
      RangeRepFeedbackCode.waitForBody ||
      RangeRepFeedbackCode.bodyNotVisible => FeedbackPriority.systemState,
      RangeRepFeedbackCode.descend ||
      RangeRepFeedbackCode.ascend ||
      RangeRepFeedbackCode.repCompleted ||
      RangeRepFeedbackCode.repIncomplete => FeedbackPriority.movement,
      RangeRepFeedbackCode.legacyFormThresholdViolation ||
      RangeRepFeedbackCode.controlDescent ||
      RangeRepFeedbackCode.controlAscent ||
      RangeRepFeedbackCode.stabilizeTransition ||
      RangeRepFeedbackCode.maintainForm => FeedbackPriority.corrective,
    };
  }

  void _recordPrimaryExtrema(double value) {
    if (value < _currentRepMinAngle) {
      _currentRepMinAngle = value;
    }
    if (value > _currentRepMaxAngle) {
      _currentRepMaxAngle = value;
    }
  }

  double get _peakMetricForCurrentRep => switch (primaryMetricDirection) {
    RangeRepPrimaryMetricDirection.decreasingToPeak => _currentRepMinAngle,
    RangeRepPrimaryMetricDirection.increasingToPeak => _currentRepMaxAngle,
  };

  String get _phaseGateStatus {
    final pendingTransition = _genericRepEngine.pendingTransition;
    final pendingStartedAt = _genericRepEngine.pendingTransitionStartedAt;
    final requiredDuration =
        _genericRepEngine.pendingTransitionRequiredDuration;
    if (pendingTransition == null ||
        pendingStartedAt == null ||
        requiredDuration == null) {
      return _isArmed ? 'stable ${state.name}' : 'stable awaiting neutral';
    }

    final elapsedMs = _now().difference(pendingStartedAt).inMilliseconds;
    final requiredMs = requiredDuration.inMilliseconds;

    return 'confirming ${pendingTransition.legacyDebugLabel} '
        '(${elapsedMs}ms/${requiredMs}ms)';
  }

  @override
  void beginBriefVisibilityGap() {
    if (_briefVisibilityGapWindow.isActive) {
      return;
    }

    _briefVisibilityGapWindow.begin(_now());
    _briefVisibilityGapFrozenPhase = state;
    _briefVisibilityGapWasArmed = _isArmed;
    _genericRepEngine.cancelPendingTransition();
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
    _genericRepEngine.reset();
    _tempoEngine.reset();
    repCount = _genericRepEngine.repCount;
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
    _genericRepEngine.clearActiveRepContext();
    _tempoEngine.interrupt();
    _isArmed = _genericRepEngine.isArmed;
    state = _movementPhaseFor(_genericRepEngine.phase);
    repCount = _genericRepEngine.repCount;
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
    final genericPhase = switch (frozenPhase) {
      MovementPhase.neutral => GenericRepPhase.neutral,
      MovementPhase.descending => GenericRepPhase.towardPeak,
      MovementPhase.peak => GenericRepPhase.peak,
      MovementPhase.ascending => GenericRepPhase.returning,
    };
    return _genericRepEngine.isMetricCompatibleWithPhase(
      primaryMetric,
      frozenPhase: genericPhase,
      wasArmed: wasArmed,
    );
  }

  void _shiftActivePhaseTiming(Duration gapDuration) {
    if (gapDuration <= Duration.zero) {
      return;
    }

    _tempoEngine.shiftActiveTiming(gapDuration);

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
