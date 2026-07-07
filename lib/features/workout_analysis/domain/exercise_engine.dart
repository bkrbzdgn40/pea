import 'analysis_engine.dart';
import 'models/exercise_config.dart';
import 'models/analysis_frame.dart';
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

/// Current range-rep style engine backing the squat analysis flow.
///
/// The class name is intentionally kept stable for now to avoid rename churn
/// while the multi-engine seam settles.
class ExerciseEngine
    implements AnalysisEngine, RangeRepDiagnostics, RangeRepResyncControl {
  final ExerciseConfig config;

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

  ExerciseEngine({required this.config});

  @override
  double get maxRom => maxROM;

  @override
  String get phaseLabel => state.name.toUpperCase();

  @override
  RangeRepDiagnosticsSnapshot get diagnosticsSnapshot =>
      RangeRepDiagnosticsSnapshot(
        currentRepWorstBackAngle: _currentRepWorstBackAngle,
        currentRepHadFormViolation: _currentRepHadFormViolation,
        phaseGateStatus: _phaseGateStatus,
        pendingTransitionLabel: _pendingTransition?.debugLabel,
        lastConfirmedTransitionLabel: _lastConfirmedTransitionLabel,
        lastRepScoreBreakdown: lastRepScoreBreakdown,
      );

  /// Updates live form feedback and advances the repetition state machine.
  @override
  void update(AnalysisFrame frame) {
    _checkForm(frame.formMetric);
    _processState(frame.primaryMetric, frame.formMetric);
  }

  void _processState(double angle, double backAngle) {
    final now = DateTime.now();

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
          _startRepMetrics(angle, backAngle);
          feedback = "Asagi in...";
        }
        break;

      case MovementPhase.descending:
        _trackRepForm(backAngle);
        if (angle < _currentRepMinAngle) _currentRepMinAngle = angle;

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
            feedback = "Hareketi tamamlamadin.";
          }
        }
        break;

      case MovementPhase.peak:
        _trackRepForm(backAngle);
        if (angle < _currentRepMinAngle) _currentRepMinAngle = angle;

        final ascentConfirmedAt = _confirmTransition(
          transition: _PhaseTransition.startAscending,
          condition: angle > _peakExitThreshold,
          now: now,
        );
        if (ascentConfirmedAt != null) {
          state = MovementPhase.ascending;
          _ascentStartTime = ascentConfirmedAt;
          feedback = "Yukari...";
        }
        break;

      case MovementPhase.ascending:
        _trackRepForm(backAngle);
        final repCompleteAt = _confirmTransition(
          transition: _PhaseTransition.completeRep,
          condition: angle > _neutralReturnThreshold,
          now: now,
        );
        if (repCompleteAt != null) {
          if (_ascentStartTime != null) {
            lastAscentTime = repCompleteAt.difference(_ascentStartTime!);
          }
          _finishRep();
          state = MovementPhase.neutral;
          feedback = "Basarili!";
        }
        break;
    }
  }

  void _finishRep() {
    // Score is finalized only after descent, peak, and ascent return to neutral.
    repCount++;
    maxROM = _currentRepMinAngle;

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

    // Keep the penalty binary, but base it on full rep history, not the last frame.
    final finalScore = _currentRepHadFormViolation
        ? (romScore + tempoScore) / 4
        : (romScore + tempoScore) / 2;

    lastRepScore = finalScore;
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

  void _startRepMetrics(double angle, double backAngle) {
    _currentRepMinAngle = angle;
    _currentRepWorstBackAngle = backAngle;
    _currentRepHadFormViolation = backAngle < config.formThreshold;
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
    _clearPendingTransition();
  }

  void _checkForm(double backAngle) {
    // Live feedback uses the current frame; final scoring uses rep-level history.
    if (backAngle < config.formThreshold) {
      isFormBad = true;
      feedback = "Sirtini Dik Tut!";
    } else {
      isFormBad = false;
    }
  }

  double get _descentEntryThreshold => config.thresholdActive - _descentEntryMargin;

  double get _peakEntryThreshold => config.thresholdPeak - _peakEntryMargin;

  double get _peakExitThreshold => config.thresholdPeak + _peakExitMargin;

  double get _neutralReturnThreshold => config.thresholdNeutral;

  String get _phaseGateStatus {
    if (_pendingTransition == null || _pendingTransitionStartedAt == null) {
      return 'stable ${state.name}';
    }

    final elapsedMs = DateTime.now()
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

    if (_pendingTransition != transition || _pendingTransitionStartedAt == null) {
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
    feedback = "Hazir!";
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
    maxROM = 180;
    lastDescentTime = Duration.zero;
    lastAscentTime = Duration.zero;
    _descentStartTime = null;
    _peakStartTime = null;
    _ascentStartTime = null;
    _lastConfirmedTransitionLabel = null;
    _resetCurrentRepMetrics();
  }
}
