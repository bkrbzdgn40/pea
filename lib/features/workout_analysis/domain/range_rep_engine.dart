import 'feedback_arbitration_engine.dart';
import 'generic_rep_engine.dart';
import 'legacy_range_rep_technique_evaluator.dart';
import 'models/exercise_config.dart';
import 'models/analysis_frame.dart';
import 'models/range_rep_aborted_attempt_detection_data.dart';
import 'models/range_rep_completed_cycle.dart';
import 'models/range_rep_completed_rep_detection_data.dart';
import 'models/range_rep_confirmed_transition.dart';
import 'models/range_rep_contract.dart';
import 'models/range_rep_engine_frame_result.dart';
import 'models/range_rep_feedback_code.dart';
import 'models/range_rep_technique_assessment.dart';
import 'models/rep_score_breakdown.dart';
import 'range_rep_analysis_engine.dart';
import 'range_rep_diagnostics.dart';
import 'range_rep_legacy_score_tracker.dart';
import 'range_rep_phase_quality_tracker.dart';
import 'range_rep_timing_lifecycle.dart';
import 'range_rep_visibility_lifecycle.dart';
import 'tempo_measurement_eligibility_policy.dart';
import 'tempo_engine.dart';

enum MovementPhase { neutral, descending, peak, ascending }

extension _GenericRepTransitionX on GenericRepTransitionType {
  RangeRepConfirmedTransition confirmedAt({
    required DateTime effectiveAt,
    required DateTime confirmedAt,
  }) {
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
    return RangeRepConfirmedTransition(
      type: type,
      effectiveAt: effectiveAt,
      confirmedAt: confirmedAt,
    );
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
    required this.abortedAttemptDetectionData,
    required this.completedRepDetectionData,
    required this.completedRepCoreData,
    required this.completedCycle,
    required List<RangeRepConfirmedTransition> confirmedTransitions,
    required List<RangeRepPhase> observedRepPhases,
    this.completedTempo,
  }) : confirmedTransitions = List<RangeRepConfirmedTransition>.unmodifiable(
         confirmedTransitions,
       ),
       observedRepPhases = List<RangeRepPhase>.unmodifiable(observedRepPhases);

  final bool repStarted;
  final bool repAborted;
  final RangeRepAbortedAttemptDetectionData? abortedAttemptDetectionData;
  final RangeRepCompletedRepDetectionData? completedRepDetectionData;
  final RangeRepCompletedRepCoreData? completedRepCoreData;
  final RangeRepCompletedCycle? completedCycle;
  final List<RangeRepConfirmedTransition> confirmedTransitions;
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

/// Current range-rep engine backing the workout analysis flow.
class RangeRepEngine implements RangeRepAnalysisEngine, TempoMetricsSource {
  final ExerciseConfig config;
  final RangeRepPrimaryMetricDirection primaryMetricDirection;
  final DateTime Function() _now;
  final LegacyRangeRepTechniqueEvaluator _techniqueEvaluator =
      const LegacyRangeRepTechniqueEvaluator();
  final FeedbackArbitrationEngine _feedbackArbitrationEngine =
      const FeedbackArbitrationEngine();

  MovementPhase state = MovementPhase.neutral;
  bool _isArmed = false;
  bool _peakEntryAllowed = true;
  @override
  int repCount = 0;
  bool isFormBad = false;

  // Compatibility ROM value for the most recently completed repetition.
  double _lastRepRom = 180.0;
  double get lastRepScore => _legacyScoreTracker.lastRepScore;

  set lastRepScore(double value) {
    _legacyScoreTracker.lastRepScore = value;
  }

  RepScoreBreakdown? get lastRepScoreBreakdown =>
      _legacyScoreTracker.lastRepScoreBreakdown;

  set lastRepScoreBreakdown(RepScoreBreakdown? value) {
    _legacyScoreTracker.lastRepScoreBreakdown = value;
  }

  RangeRepCompletedRepCoreData? lastCompletedRepCoreData;
  RangeRepCompletedRepCoreData? _pendingCompletedRepCoreData;
  late String feedback;
  RangeRepFeedbackCode? _feedbackCode;

  DateTime? _descentStartTime;
  DateTime? _peakStartTime;
  DateTime? _ascentStartTime;
  late final RangeRepVisibilityLifecycle _visibilityLifecycle;

  Duration lastDescentTime = Duration.zero;
  Duration lastAscentTime = Duration.zero;

  double? _currentRepStartAngle;
  double _currentRepMinAngle = 180.0;
  double _currentRepWorstBackAngle = 180.0;
  bool _currentRepHadFormViolation = false;
  late final GenericRepEngine _genericRepEngine;
  late final TempoEngine _tempoEngine;
  String? _lastConfirmedTransitionLabel;
  late final RangeRepLegacyScoreTracker _legacyScoreTracker;
  late final RangeRepPhaseQualityTracker _phaseQualityTracker;
  late final RangeRepTimingLifecycle _timingLifecycle;

  RangeRepEngine({
    required this.config,
    this.primaryMetricDirection =
        RangeRepPrimaryMetricDirection.decreasingToPeak,
    RangeRepTowardPeakMuscleAction towardPeakMuscleAction =
        RangeRepTowardPeakMuscleAction.eccentric,
    double activeEntryMargin = 3.0,
    double peakEntryMargin = 3.0,
    double peakExitMargin = 8.0,
    double? completionThreshold,
    bool retainPeakEvidenceAcrossActiveTransition = false,
    bool allowSparseCycleRecovery = false,
    Duration initialNeutralConfirmationDuration = const Duration(
      milliseconds: 100,
    ),
    Duration returnConfirmationDuration = const Duration(milliseconds: 80),
    Duration neutralConfirmationDuration = const Duration(milliseconds: 100),
    Duration neutralBaselineWindow = Duration.zero,
    double neutralBaselineThresholdMargin = 0.0,
    TempoMeasurementEligibilityConfig tempoMeasurementEligibilityConfig =
        const TempoMeasurementEligibilityConfig(),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now {
    _legacyScoreTracker = RangeRepLegacyScoreTracker(
      config: config,
      primaryMetricDirection: primaryMetricDirection,
    );
    _phaseQualityTracker = RangeRepPhaseQualityTracker(config: config);
    _timingLifecycle = RangeRepTimingLifecycle(
      eligibilityConfig: tempoMeasurementEligibilityConfig,
    );
    _visibilityLifecycle = RangeRepVisibilityLifecycle(
      graceDuration: rangeRepVisibilityGapGraceDuration,
      now: _now,
    );
    _genericRepEngine = GenericRepEngine(
      config: GenericRepEngineConfig(
        neutralThreshold: config.thresholdNeutral,
        activeThreshold: config.thresholdActive,
        peakThreshold: config.thresholdPeak,
        activeEntryMargin: activeEntryMargin,
        peakEntryMargin: peakEntryMargin,
        peakExitMargin: peakExitMargin,
        completionThreshold: completionThreshold,
        retainPeakEvidenceAcrossActiveTransition:
            retainPeakEvidenceAcrossActiveTransition,
        allowSparseCycleRecovery: allowSparseCycleRecovery,
        initialNeutralConfirmationDuration: initialNeutralConfirmationDuration,
        returnConfirmationDuration: returnConfirmationDuration,
        neutralConfirmationDuration: neutralConfirmationDuration,
        neutralBaselineWindow: neutralBaselineWindow,
        neutralBaselineThresholdMargin: neutralBaselineThresholdMargin,
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
      activeTimingTrace: _timingLifecycle.activeSnapshot,
      lastEndedTimingTrace: _timingLifecycle.lastEndedSnapshot,
      lastTempoMeasurementAssessment: _timingLifecycle.lastAssessment,
      nonMonotonicObservationCount:
          _timingLifecycle.nonMonotonicObservationCount,
    );
  }

  RangeRepDiagnosticsSnapshot get diagnosticsSnapshot {
    final now = _now();
    final phaseQualityTelemetry =
        state == MovementPhase.neutral &&
            _genericRepEngine.pendingTransition == null
        ? (_phaseQualityTracker.lastCompletedTelemetry ??
              _phaseQualityTelemetry(now))
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
      activeTimingTrace: _timingLifecycle.activeSnapshot,
      lastEndedTimingTrace: _timingLifecycle.lastEndedSnapshot,
      lastTempoMeasurementAssessment: _timingLifecycle.lastAssessment,
      nonMonotonicObservationCount:
          _timingLifecycle.nonMonotonicObservationCount,
    );
  }

  @override
  RangeRepEngineFrameResult updateDetectionFrame({
    required double primaryMetric,
    DateTime? observedAt,
  }) {
    return _updateFrame(
      primaryMetric: primaryMetric,
      observedAt: observedAt,
      calculateCompatibilityScore: false,
    );
  }

  @override
  void setPeakEntryAllowed(bool allowed) {
    _peakEntryAllowed = allowed;
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
    DateTime? observedAt,
    double? compatibilityFormMetric,
    RangeRepTechniqueAssessment? techniqueAssessment,
    required bool calculateCompatibilityScore,
  }) {
    final processedAt = _now();
    final effectiveObservedAt = observedAt ?? processedAt;
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
      observedAt: effectiveObservedAt,
      processedAt: processedAt,
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
      abortedAttemptDetectionData: lifecycleFacts.abortedAttemptDetectionData,
      completedRepDetectionData: lifecycleFacts.completedRepDetectionData,
      completedRepCoreData: lifecycleFacts.completedRepCoreData,
      completedCycle: lifecycleFacts.completedCycle,
      confirmedTransitions: lifecycleFacts.confirmedTransitions,
      observedRepPhases: lifecycleFacts.observedRepPhases,
      completedTempo: lifecycleFacts.completedTempo,
    );
  }

  _RangeRepLifecycleFacts _processState(
    double angle, {
    required DateTime observedAt,
    required DateTime processedAt,
    required double? compatibilityFormMetric,
    required bool hasTechniqueViolation,
    required bool tracksCompatibilityTechnique,
    required bool calculateCompatibilityScore,
  }) {
    final detectionMetric =
        !_peakEntryAllowed &&
            state == MovementPhase.descending &&
            switch (primaryMetricDirection) {
              RangeRepPrimaryMetricDirection.decreasingToPeak =>
                angle < config.thresholdPeak,
              RangeRepPrimaryMetricDirection.increasingToPeak =>
                angle > config.thresholdPeak,
            }
        ? config.thresholdActive
        : angle;
    final genericResult = _genericRepEngine.update(
      primaryMetric: detectionMetric,
      observedAt: observedAt,
    );
    if (!genericResult.observationAccepted) {
      _timingLifecycle.recordRejectedObservation();
      return _RangeRepLifecycleFacts(
        repStarted: false,
        repAborted: false,
        abortedAttemptDetectionData: null,
        completedRepDetectionData: null,
        completedRepCoreData: null,
        completedCycle: null,
        confirmedTransitions: const <RangeRepConfirmedTransition>[],
        observedRepPhases: const <RangeRepPhase>[],
      );
    }
    final completedTempo = _tempoEngine.process(genericResult);
    final genericTransitions = genericResult.confirmedTransitions;
    final stateBefore = _movementPhaseFor(genericResult.phaseBeforeUpdate);

    _timingLifecycle.recordAcceptedFrame(
      result: genericResult,
      primaryMetric: angle,
      observedAt: observedAt,
      processedAt: processedAt,
    );

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
    RangeRepAbortedAttemptDetectionData? abortedAttemptDetectionData;
    RangeRepCompletedRepDetectionData? completedRepDetectionData;
    RangeRepCompletedRepCoreData? completedRepCoreData;
    RangeRepCompletedCycle? completedCycle;
    final confirmedTransitions = <RangeRepConfirmedTransition>[];

    for (final transition in genericTransitions) {
      _lastConfirmedTransitionLabel = transition.type.legacyDebugLabel;
      confirmedTransitions.add(
        transition.type.confirmedAt(
          effectiveAt: transition.effectiveAt,
          confirmedAt: transition.confirmedAt,
        ),
      );

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
          final startAngle = _currentRepStartAngle;
          final descentStartedAt = _descentStartTime;
          final rawDescentDuration = descentStartedAt == null
              ? Duration.zero
              : transition.effectiveAt.difference(descentStartedAt);
          abortedAttemptDetectionData = RangeRepAbortedAttemptDetectionData(
            minAngle: _currentRepMinAngle,
            descentDuration: rawDescentDuration.isNegative
                ? Duration.zero
                : rawDescentDuration,
            startAngle: startAngle,
            primaryRom: startAngle == null
                ? null
                : (startAngle - _currentRepMinAngle)
                      .abs()
                      .clamp(0.0, 180.0)
                      .toDouble(),
          );
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
              genericCompletedRep: genericResult.completedRep!,
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

    if (completedRepDetectionData != null) {
      final timingCompletion = _timingLifecycle.finishCompleted(completedTempo);
      final completedTimingTrace = timingCompletion.trace;
      final tempoMeasurementAssessment = timingCompletion.assessment;
      completedCycle = RangeRepCompletedCycle(
        genericCompletedRep: genericResult.completedRep!,
        detectionData: completedRepDetectionData,
        compatibilityCoreData: completedRepCoreData,
        completedTempo: completedTempo,
        timingTrace: completedTimingTrace,
        tempoMeasurementAssessment: tempoMeasurementAssessment,
        phaseQualityTelemetry: tracksCompatibilityTechnique
            ? _phaseQualityTracker.lastCompletedTelemetry
            : null,
        confirmedTransitions: confirmedTransitions,
      );
    } else if (repAborted) {
      _timingLifecycle.finishAborted();
    }

    return _RangeRepLifecycleFacts(
      repStarted: repStarted,
      repAborted: repAborted,
      abortedAttemptDetectionData: abortedAttemptDetectionData,
      completedRepDetectionData: completedRepDetectionData,
      completedRepCoreData: completedRepCoreData,
      completedCycle: completedCycle,
      confirmedTransitions: confirmedTransitions,
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

  RangeRepPhase? _rangeRepPhaseForMovement(MovementPhase phase) {
    return switch (phase) {
      MovementPhase.neutral => null,
      MovementPhase.descending => RangeRepPhase.descending,
      MovementPhase.peak => RangeRepPhase.peak,
      MovementPhase.ascending => RangeRepPhase.ascending,
    };
  }

  _RangeRepCompletionFacts _finishRep({
    required GenericRepCompletedRep genericCompletedRep,
    required bool tracksCompatibilityTechnique,
    required bool calculateCompatibilityScore,
  }) {
    _lastRepRom = _currentRepMinAngle;
    final completedPhaseSequence =
        _descentStartTime != null &&
        _peakStartTime != null &&
        _ascentStartTime != null;
    final primaryRom = genericCompletedRep.rom.clamp(0.0, 180.0).toDouble();
    final detectionData = RangeRepCompletedRepDetectionData(
      repIndex: repCount,
      minAngle: _lastRepRom,
      descentDuration: lastDescentTime,
      ascentDuration: lastAscentTime,
      completedPhaseSequence: completedPhaseSequence,
      startAngle: genericCompletedRep.startMetric,
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
    _legacyScoreTracker.calculate(
      completedRepCoreData: completedRepCoreData,
      descendingPhaseAssessment: descendingPhaseAssessment,
      ascendingPhaseAssessment: ascendingPhaseAssessment,
    );
  }

  RangeRepPhaseQualityTelemetry _phaseQualityTelemetry(DateTime now) {
    return _phaseQualityTracker.telemetry(
      now: now,
      activePhase: _rangeRepPhaseForMovement(state),
    );
  }

  RangeRepPhaseQualityTelemetry _completedPhaseQualityTelemetry(
    DateTime capturedAt,
  ) {
    return _phaseQualityTracker.completedTelemetry(capturedAt);
  }

  RangeRepPhaseQualityAssessment _assessPhaseQuality({
    required MovementPhase phase,
    required RangeRepPhaseQualitySnapshot phaseQuality,
    required bool isActivePhase,
  }) {
    return _phaseQualityTracker.assess(
      phase: _rangeRepPhaseForMovement(phase)!,
      phaseQuality: phaseQuality,
      isActivePhase: isActivePhase,
    );
  }

  RangeRepFeedbackCode? _phaseFeedbackCodeCandidate({
    required RangeRepPhaseQualityAssessment descendingPhaseAssessment,
    required RangeRepPhaseQualityAssessment peakPhaseAssessment,
    required RangeRepPhaseQualityAssessment ascendingPhaseAssessment,
  }) {
    return _phaseQualityTracker.feedbackCandidate(
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
    _phaseQualityTracker.captureCompleted(capturedAt);
  }

  void _beginPhaseTelemetry({
    required MovementPhase phase,
    required DateTime phaseStartedAt,
    required double primaryMetric,
    required double formMetric,
    required bool hasTechniqueViolation,
  }) {
    _phaseQualityTracker.start(
      phase: _rangeRepPhaseForMovement(phase)!,
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
    _phaseQualityTracker.record(
      phase: _rangeRepPhaseForMovement(phase)!,
      primaryMetric: primaryMetric,
      formMetric: formMetric,
      hadFormViolation: hasTechniqueViolation,
    );
  }

  void _completePhaseTelemetry({
    required MovementPhase phase,
    required DateTime phaseEndedAt,
  }) {
    _phaseQualityTracker.complete(
      phase: _rangeRepPhaseForMovement(phase)!,
      endedAt: phaseEndedAt,
    );
  }

  void _resetPhaseQualityTelemetry() {
    _phaseQualityTracker.reset();
  }

  void _startDetectionRepMetrics(double primaryMetric) {
    _currentRepStartAngle = primaryMetric;
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
    _currentRepStartAngle = null;
    _currentRepMinAngle = 180.0;
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
  }

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
  void beginBriefVisibilityGap({DateTime? observedAt}) {
    _visibilityLifecycle.begin(
      engine: _genericRepEngine,
      observedAt: observedAt,
      onGapStarted: _timingLifecycle.markVisibilityGap,
    );
  }

  @override
  VisibilityGapResumeResult resumeAfterBriefVisibilityGap({
    required double primaryMetric,
    DateTime? observedAt,
  }) {
    return _visibilityLifecycle.resume(
      engine: _genericRepEngine,
      primaryMetric: primaryMetric,
      observedAt: observedAt,
      onCompatibleGap: _shiftActivePhaseTiming,
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
    _legacyScoreTracker.reset();
    lastCompletedRepCoreData = null;
    _pendingCompletedRepCoreData = null;
    _lastRepRom = 180;
    lastDescentTime = Duration.zero;
    lastAscentTime = Duration.zero;
    _descentStartTime = null;
    _peakStartTime = null;
    _ascentStartTime = null;
    _visibilityLifecycle.reset();
    _phaseQualityTracker.resetAll();
    _timingLifecycle.reset();
    _disarm();
  }

  void _disarm() {
    _timingLifecycle.finishInterrupted();
    _peakEntryAllowed = true;
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
    _visibilityLifecycle.reset();
    _lastConfirmedTransitionLabel = null;
    _resetCurrentRepMetrics();
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
        _phaseQualityTracker.shiftStartedAt(
          phase: RangeRepPhase.descending,
          delta: gapDuration,
        );
        break;
      case MovementPhase.peak:
        if (_peakStartTime != null) {
          _peakStartTime = _peakStartTime!.add(gapDuration);
        }
        _phaseQualityTracker.shiftStartedAt(
          phase: RangeRepPhase.peak,
          delta: gapDuration,
        );
        break;
      case MovementPhase.ascending:
        if (_ascentStartTime != null) {
          _ascentStartTime = _ascentStartTime!.add(gapDuration);
        }
        _phaseQualityTracker.shiftStartedAt(
          phase: RangeRepPhase.ascending,
          delta: gapDuration,
        );
        break;
    }
  }
}
