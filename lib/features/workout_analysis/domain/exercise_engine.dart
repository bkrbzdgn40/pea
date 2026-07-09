import 'analysis_engine.dart';
import 'models/exercise_config.dart';
import 'models/analysis_frame.dart';
import 'models/range_rep_feedback_code.dart';
import 'models/rep_score_breakdown.dart';
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
  startDescending,
  reachPeak,
  startAscending,
  abortToNeutral,
  completeRep,
}

extension _PhaseTransitionX on _PhaseTransition {
  Duration get confirmationDuration {
    switch (this) {
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

class _WeightedScoreComponent {
  const _WeightedScoreComponent({required this.score, required this.weight});

  final double? score;
  final double weight;
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

/// Current range-rep style engine backing the squat analysis flow.
///
/// The class name is intentionally kept stable for now to avoid rename churn
/// while the multi-engine seam settles.
class ExerciseEngine
    implements AnalysisEngine, RangeRepDiagnostics, RangeRepResyncControl {
  final ExerciseConfig config;
  final DateTime Function() _now;

  MovementPhase state = MovementPhase.neutral;
  @override
  int repCount = 0;
  @override
  bool isFormBad = false;

  // Kept for WorkoutController compatibility; this is the last rep's min angle.
  double maxROM = 180.0;
  @override
  double lastRepScore = 0.0;
  RepScoreBreakdown? lastRepScoreBreakdown;
  RangeRepCompletedRepCoreData? lastCompletedRepCoreData;
  @override
  String feedback = "Hazir!";

  DateTime? _descentStartTime;
  DateTime? _peakStartTime;
  DateTime? _ascentStartTime;

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

  ExerciseEngine({required this.config, DateTime Function()? now})
    : _now = now ?? DateTime.now;

  @override
  double get maxRom => maxROM;

  @override
  String get phaseLabel => state.name.toUpperCase();

  @override
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
      hasActiveRepPhase: state != MovementPhase.neutral,
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

  /// Updates live form feedback and advances the repetition state machine.
  @override
  void update(AnalysisFrame frame) {
    _checkForm(frame.formMetric);
    _processState(frame.primaryMetric, frame.formMetric);
  }

  void _processState(double angle, double backAngle) {
    final now = _now();

    // Aborted descents reset to neutral without counting a repetition.
    switch (state) {
      case MovementPhase.neutral:
        final confirmedAt = _confirmTransition(
          transition: _PhaseTransition.startDescending,
          condition: angle < _descentEntryThreshold,
          now: now,
        );
        if (confirmedAt != null) {
          state = MovementPhase.descending;
          _descentStartTime = confirmedAt;
          _startRepMetrics(angle, backAngle, phaseStartedAt: confirmedAt);
          feedback = _feedbackMessageForCode(RangeRepFeedbackCode.descend);
        }
        break;

      case MovementPhase.descending:
        _trackRepForm(backAngle);
        if (angle < _currentRepMinAngle) _currentRepMinAngle = angle;
        _recordPhaseObservation(
          phase: MovementPhase.descending,
          primaryMetric: angle,
          formMetric: backAngle,
        );

        final peakConfirmedAt = _confirmTransition(
          transition: _PhaseTransition.reachPeak,
          condition: angle < _peakEntryThreshold,
          now: now,
        );
        if (peakConfirmedAt != null) {
          state = MovementPhase.peak;
          _peakStartTime = peakConfirmedAt;
          if (_descentStartTime != null) {
            lastDescentTime = _peakStartTime!.difference(_descentStartTime!);
          }
          _completePhaseTelemetry(
            phase: MovementPhase.descending,
            phaseEndedAt: peakConfirmedAt,
          );
          _beginPhaseTelemetry(
            phase: MovementPhase.peak,
            phaseStartedAt: peakConfirmedAt,
            primaryMetric: angle,
            formMetric: backAngle,
          );
          feedback = "Harika, simdi yukari!";
        } else {
          final abortConfirmedAt = _confirmTransition(
            transition: _PhaseTransition.abortToNeutral,
            condition: angle > _neutralReturnThreshold,
            now: now,
          );
          if (abortConfirmedAt != null) {
            state = MovementPhase.neutral;
            _resetCurrentRepMetrics();
            feedback = _feedbackMessageForCode(
              RangeRepFeedbackCode.repIncomplete,
            );
          }
        }
        break;

      case MovementPhase.peak:
        _trackRepForm(backAngle);
        if (angle < _currentRepMinAngle) _currentRepMinAngle = angle;
        _recordPhaseObservation(
          phase: MovementPhase.peak,
          primaryMetric: angle,
          formMetric: backAngle,
        );

        final ascentConfirmedAt = _confirmTransition(
          transition: _PhaseTransition.startAscending,
          condition: angle > _peakExitThreshold,
          now: now,
        );
        if (ascentConfirmedAt != null) {
          state = MovementPhase.ascending;
          _ascentStartTime = ascentConfirmedAt;
          _completePhaseTelemetry(
            phase: MovementPhase.peak,
            phaseEndedAt: ascentConfirmedAt,
          );
          _beginPhaseTelemetry(
            phase: MovementPhase.ascending,
            phaseStartedAt: ascentConfirmedAt,
            primaryMetric: angle,
            formMetric: backAngle,
          );
          feedback = _feedbackMessageForCode(RangeRepFeedbackCode.ascend);
        }
        break;

      case MovementPhase.ascending:
        _trackRepForm(backAngle);
        _recordPhaseObservation(
          phase: MovementPhase.ascending,
          primaryMetric: angle,
          formMetric: backAngle,
        );
        final repCompleteAt = _confirmTransition(
          transition: _PhaseTransition.completeRep,
          condition: angle > _neutralReturnThreshold,
          now: now,
        );
        if (repCompleteAt != null) {
          if (_ascentStartTime != null) {
            lastAscentTime = repCompleteAt.difference(_ascentStartTime!);
          }
          _completePhaseTelemetry(
            phase: MovementPhase.ascending,
            phaseEndedAt: repCompleteAt,
          );
          _finishRep();
          state = MovementPhase.neutral;
          _captureLastCompletedPhaseQualityTelemetry(repCompleteAt);
        }
        break;
    }
  }

  void _finishRep() {
    // Score is finalized only after descent, peak, and ascent return to neutral.
    repCount++;
    maxROM = _currentRepMinAngle;
    final completedPhaseSequence =
        _descentStartTime != null &&
        _peakStartTime != null &&
        _ascentStartTime != null;

    final romScore = _calculateRomScore(maxROM);
    final descentSeconds = lastDescentTime.inMilliseconds / 1000.0;
    final descentScore = _calculateTempoScore(
      actualSeconds: descentSeconds,
      idealSeconds: config.idealDescentSeconds,
    );
    final ascentSeconds = lastAscentTime.inMilliseconds / 1000.0;
    final ascentScoreCandidate = _calculateTempoScore(
      actualSeconds: ascentSeconds,
      idealSeconds: config.idealAscentSeconds,
    );
    final tempoScore = (descentScore + ascentScoreCandidate) / 2;
    final descentControlScore = descentScore;
    final ascentControlScore = ascentScoreCandidate;
    final scoreWeights = config.rangeRepScoreWeights;
    final weightedScoreCandidate =
        _composeWeightedScore(<_WeightedScoreComponent>[
          _WeightedScoreComponent(
            score: descentControlScore,
            weight: scoreWeights?.descentControlWeight ?? 1.0,
          ),
          _WeightedScoreComponent(
            score: ascentControlScore,
            weight: scoreWeights?.ascentControlWeight ?? 1.0,
          ),
        ]);
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
    final phaseQualityPenaltyCandidate = _phaseQualityPenaltyCandidate(
      descendingPhaseAssessment: descendingPhaseAssessment,
      ascendingPhaseAssessment: ascendingPhaseAssessment,
    );
    final phaseFeedbackCodeCandidate = _phaseFeedbackCodeCandidate(
      descendingPhaseAssessment: descendingPhaseAssessment,
      peakPhaseAssessment: peakPhaseAssessment,
      ascendingPhaseAssessment: ascendingPhaseAssessment,
    );

    // Phase-aware score now becomes the runtime score when a completed rep is flagged.
    final baseScore = _currentRepHadFormViolation
        ? (romScore + tempoScore) / 4
        : (romScore + tempoScore) / 2;
    final phaseInformedScoreCandidate = phaseQualityPenaltyCandidate == null
        ? null
        : (baseScore - phaseQualityPenaltyCandidate).clamp(0.0, 100.0).toDouble();
    final finalScore = phaseInformedScoreCandidate ?? baseScore;

    lastRepScore = finalScore;
    feedback = _feedbackMessageForCode(
      phaseFeedbackCodeCandidate ?? RangeRepFeedbackCode.repCompleted,
    );
    lastRepScoreBreakdown = RepScoreBreakdown(
      minAngle: maxROM,
      romScore: romScore,
      descentSeconds: descentSeconds,
      descentScore: descentScore,
      ascentSeconds: ascentSeconds,
      ascentScoreCandidate: ascentScoreCandidate,
      worstBackAngle: _currentRepWorstBackAngle,
      hadFormViolation: _currentRepHadFormViolation,
      finalScore: finalScore,
      descentControlScore: descentControlScore,
      ascentControlScore: ascentControlScore,
      weightedScoreCandidate: weightedScoreCandidate,
      phaseQualityPenaltyCandidate: phaseQualityPenaltyCandidate,
      phaseInformedScoreCandidate: phaseInformedScoreCandidate,
    );
    lastCompletedRepCoreData = RangeRepCompletedRepCoreData(
      repIndex: repCount,
      minAngle: maxROM,
      worstFormMetric: _currentRepWorstBackAngle,
      descentDuration: lastDescentTime,
      ascentDuration: lastAscentTime,
      hadFormViolation: _currentRepHadFormViolation,
      completedPhaseSequence: completedPhaseSequence,
    );
  }

  double _calculateRomScore(double minAngle) {
    return (100 - (minAngle - config.targetMinAngle)).clamp(0, 100).toDouble();
  }

  double _calculateTempoScore({
    required double actualSeconds,
    required double idealSeconds,
  }) {
    return (100 -
            (idealSeconds - actualSeconds).abs() * config.tempoPenaltyPerSecond)
        .clamp(0, 100)
        .toDouble();
  }

  double? _composeWeightedScore(Iterable<_WeightedScoreComponent> components) {
    var weightedScoreTotal = 0.0;
    var totalWeight = 0.0;

    for (final component in components) {
      final score = component.score;
      if (score == null || component.weight <= 0) {
        continue;
      }

      weightedScoreTotal += score * component.weight;
      totalWeight += component.weight;
    }

    if (totalWeight <= 0) {
      return null;
    }

    return weightedScoreTotal / totalWeight;
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
    if (!phaseQuality.hasData) {
      return const RangeRepPhaseQualityAssessment();
    }

    final issues = <RangeRepPhaseQualityIssue>[];
    final phaseQualityConfig = config.rangeRepPhaseQuality;

    if (!isActivePhase) {
      int? minDurationMillis;
      switch (phase) {
        case MovementPhase.descending:
          minDurationMillis = phaseQualityConfig?.minDescendingMillis;
          break;
        case MovementPhase.ascending:
          minDurationMillis = phaseQualityConfig?.minAscendingMillis;
          break;
        case MovementPhase.neutral:
        case MovementPhase.peak:
          minDurationMillis = null;
          break;
      }
      if (minDurationMillis != null &&
          phaseQuality.durationMs < minDurationMillis) {
        issues.add(RangeRepPhaseQualityIssue.durationTooShort);
      }
    }

    if (phaseQuality.hadFormViolation) {
      issues.add(RangeRepPhaseQualityIssue.formViolation);
    }

    return RangeRepPhaseQualityAssessment(
      status: issues.isEmpty
          ? RangeRepPhaseQualityStatus.observed
          : RangeRepPhaseQualityStatus.flagged,
      issues: issues,
    );
  }

  double? _phaseQualityPenaltyCandidate({
    required RangeRepPhaseQualityAssessment descendingPhaseAssessment,
    required RangeRepPhaseQualityAssessment ascendingPhaseAssessment,
  }) {
    var penalty = 0.0;

    if (descendingPhaseAssessment.status ==
        RangeRepPhaseQualityStatus.flagged) {
      penalty += 5.0;
    }
    if (ascendingPhaseAssessment.status == RangeRepPhaseQualityStatus.flagged) {
      penalty += 5.0;
    }

    return penalty > 0 ? penalty : null;
  }

  RangeRepFeedbackCode? _phaseFeedbackCodeCandidate({
    required RangeRepPhaseQualityAssessment descendingPhaseAssessment,
    required RangeRepPhaseQualityAssessment peakPhaseAssessment,
    required RangeRepPhaseQualityAssessment ascendingPhaseAssessment,
  }) {
    if (descendingPhaseAssessment.issues.contains(
      RangeRepPhaseQualityIssue.durationTooShort,
    )) {
      return RangeRepFeedbackCode.controlDescent;
    }
    if (ascendingPhaseAssessment.issues.contains(
      RangeRepPhaseQualityIssue.durationTooShort,
    )) {
      return RangeRepFeedbackCode.controlAscent;
    }
    if (peakPhaseAssessment.issues.contains(
      RangeRepPhaseQualityIssue.formViolation,
    )) {
      return RangeRepFeedbackCode.stabilizeTransition;
    }
    if (descendingPhaseAssessment.issues.contains(
          RangeRepPhaseQualityIssue.formViolation,
        ) ||
        ascendingPhaseAssessment.issues.contains(
          RangeRepPhaseQualityIssue.formViolation,
        )) {
      return RangeRepFeedbackCode.maintainForm;
    }

    return null;
  }

  String _feedbackMessageForCode(RangeRepFeedbackCode code) {
    switch (code) {
      case RangeRepFeedbackCode.ready:
        return 'Hazir!';
      case RangeRepFeedbackCode.waitForBody:
        return 'Vucut Bekleniyor...';
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
  }) {
    _phaseQualityFor(phase).start(
      startedAt: phaseStartedAt,
      primaryMetric: primaryMetric,
      formMetric: formMetric,
      hadFormViolation: formMetric < config.formThreshold,
    );
  }

  void _recordPhaseObservation({
    required MovementPhase phase,
    required double primaryMetric,
    required double formMetric,
  }) {
    _phaseQualityFor(phase).record(
      primaryMetric: primaryMetric,
      formMetric: formMetric,
      hadFormViolation: formMetric < config.formThreshold,
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

  void _startRepMetrics(
    double angle,
    double backAngle, {
    required DateTime phaseStartedAt,
  }) {
    _currentRepMinAngle = angle;
    _currentRepWorstBackAngle = backAngle;
    _currentRepHadFormViolation = backAngle < config.formThreshold;
    _resetPhaseQualityTelemetry();
    _beginPhaseTelemetry(
      phase: MovementPhase.descending,
      phaseStartedAt: phaseStartedAt,
      primaryMetric: angle,
      formMetric: backAngle,
    );
  }

  void _trackRepForm(double backAngle) {
    if (backAngle < _currentRepWorstBackAngle) {
      _currentRepWorstBackAngle = backAngle;
    }
    if (backAngle < config.formThreshold) {
      _currentRepHadFormViolation = true;
    }
  }

  void _resetCurrentRepMetrics() {
    _currentRepMinAngle = 180.0;
    _currentRepWorstBackAngle = 180.0;
    _currentRepHadFormViolation = false;
    _resetPhaseQualityTelemetry();
    _clearPendingTransition();
  }

  void _checkForm(double backAngle) {
    // Live feedback uses the current frame; final scoring uses rep-level history.
    if (backAngle < config.formThreshold) {
      isFormBad = true;
      feedback = _feedbackMessageForCode(RangeRepFeedbackCode.keepBodyUpright);
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
      return 'stable ${state.name}';
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
  void clearActiveRepContext({String? reason}) {
    state = MovementPhase.neutral;
    isFormBad = false;
    feedback = _feedbackMessageForCode(RangeRepFeedbackCode.ready);
    _descentStartTime = null;
    _peakStartTime = null;
    _ascentStartTime = null;
    _lastConfirmedTransitionLabel = null;
    _resetCurrentRepMetrics();
  }

  @override
  void reset() {
    repCount = 0;
    state = MovementPhase.neutral;
    feedback = "Sifirlandi";
    isFormBad = false;
    lastRepScore = 0;
    lastRepScoreBreakdown = null;
    lastCompletedRepCoreData = null;
    maxROM = 180;
    lastDescentTime = Duration.zero;
    lastAscentTime = Duration.zero;
    _descentStartTime = null;
    _peakStartTime = null;
    _ascentStartTime = null;
    _lastCompletedPhaseQualityTelemetry = null;
    _lastConfirmedTransitionLabel = null;
    _resetCurrentRepMetrics();
  }
}
