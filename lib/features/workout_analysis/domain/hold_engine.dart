import 'dart:math' as math;

import 'analysis_visibility_gap_window.dart';
import 'hold_form_policy.dart';
import 'hold_analysis_engine.dart';
import 'hold_diagnostics.dart';
import 'models/analysis_frame.dart';
import 'models/hold_feedback_code.dart';
import 'models/hold_phase.dart';
import 'models/hold_contract.dart';
import 'models/hold_signal_values.dart';
import 'stability_engine.dart';

/// First real non-repetition engine family backed by typed hold diagnostics.
class HoldEngine
    implements HoldAnalysisEngine, StabilityMetricsSource<HoldSignal> {
  HoldEngine({
    required HoldFormPolicy posturePolicy,
    DateTime Function()? now,
    StabilityEngineConfig stabilityConfig = const StabilityEngineConfig(),
  }) : _now = now ?? DateTime.now,
       _posturePolicy = posturePolicy,
       _stabilityEngine = StabilityEngine<HoldSignal>(config: stabilityConfig);

  final DateTime Function() _now;
  final HoldFormPolicy _posturePolicy;
  final StabilityEngine<HoldSignal> _stabilityEngine;

  HoldPhase _phase = HoldPhase.ready;
  DateTime? _holdStartedAt;
  double _currentHoldSeconds = 0.0;
  double _bestHoldSeconds = 0.0;
  bool _hadFormBreak = false;
  DateTime? _misalignmentStartedAt;
  DateTime? _lastVisibleFrameAt;
  final AnalysisVisibilityGapWindow _visibilityGapWindow =
      AnalysisVisibilityGapWindow(
        graceDuration: holdVisibilityGapGraceDuration,
      );
  HoldPostureDiagnosticsSnapshot _lastVisiblePosture =
      HoldPostureDiagnosticsSnapshot();
  HoldFeedbackCode _lastCorrectiveFeedbackCodeValue =
      HoldFeedbackCode.correctForm;

  @override
  StabilitySummary<HoldSignal>? get currentStability =>
      _stabilityEngine.currentWindowSummary;

  @override
  StabilitySummary<HoldSignal>? get lastCompletedStability =>
      _stabilityEngine.lastCompletedWindow;

  @override
  StabilitySummary<HoldSignal> get stabilitySessionSummary =>
      _stabilityEngine.sessionSummary;

  @override
  HoldFeedbackCode get feedbackCode {
    switch (_phase) {
      case HoldPhase.ready:
        return HoldFeedbackCode.preparePosition;
      case HoldPhase.holding:
        if (_misalignmentStartedAt != null) {
          return _currentCorrectiveFeedbackCode();
        }
        return HoldFeedbackCode.holdPosition;
      case HoldPhase.broken:
        return _currentCorrectiveFeedbackCode();
    }
  }

  bool get isFormBad => _phase == HoldPhase.broken;

  String get feedback => feedbackCode.code;

  String get phaseLabel => _phase.legacyLabel;

  @override
  HoldDiagnosticsSnapshot get diagnosticsSnapshot => HoldDiagnosticsSnapshot(
    currentHoldSeconds: _currentHoldSeconds,
    bestHoldSeconds: _bestHoldSeconds,
    isHolding: _phase == HoldPhase.holding,
    isVisibilitySuspended: _visibilityGapWindow.isActive,
    hadFormBreak: _hadFormBreak,
    targetSignalValues: _posturePolicy.targetSignalValues(
      isHolding: _phase == HoldPhase.holding,
    ),
    phase: _phase,
    feedbackCode: feedbackCode,
    lastVisiblePosture: _lastVisiblePosture,
    isFormBreakGraceActive: _misalignmentStartedAt != null,
    currentStabilityScore: currentStability?.stabilityScore,
    lastCompletedStabilityScore: lastCompletedStability?.stabilityScore,
    sessionStabilityScore: stabilitySessionSummary.stabilityScore,
  );

  @override
  void update(AnalysisFrame frame) {
    final now = _now();
    _lastVisibleFrameAt = now;
    final evaluation = _posturePolicy.evaluate(
      frame.holdSignalValues,
      isHolding: _phase == HoldPhase.holding,
    );
    _lastVisiblePosture = evaluation.postureDiagnostics;
    _lastCorrectiveFeedbackCodeValue = evaluation.correctiveFeedbackCode;

    if (evaluation.isValidHoldPosture) {
      _misalignmentStartedAt = null;
      _startOrContinueHold(now, frame.holdSignalValues);
      return;
    }

    if (_phase == HoldPhase.holding && evaluation.supportsGraceWindow) {
      _misalignmentStartedAt ??= now;
      if (now.difference(_misalignmentStartedAt!) <
          _posturePolicy.breakGraceDuration) {
        return;
      }
    } else {
      _misalignmentStartedAt = null;
    }

    _stopActiveHoldIfNeeded();
    _misalignmentStartedAt = null;

    if (evaluation.hasActivePosture) {
      _phase = HoldPhase.broken;
      _hadFormBreak = true;
      return;
    }

    _phase = HoldPhase.ready;
    _currentHoldSeconds = 0.0;
  }

  void _startOrContinueHold(DateTime now, HoldSignalValues signals) {
    if (_phase != HoldPhase.holding || _holdStartedAt == null) {
      _holdStartedAt = now;
      _currentHoldSeconds = 0.0;
      _hadFormBreak = false;
      _stabilityEngine.beginWindow();
    } else {
      _currentHoldSeconds =
          now.difference(_holdStartedAt!).inMilliseconds / 1000.0;
    }

    _phase = HoldPhase.holding;
    _bestHoldSeconds = math.max(_bestHoldSeconds, _currentHoldSeconds);
    _stabilityEngine.recordSample(signals.asMap());
  }

  void _stopActiveHoldIfNeeded() {
    if (_phase != HoldPhase.holding) {
      return;
    }

    _bestHoldSeconds = math.max(_bestHoldSeconds, _currentHoldSeconds);
    _stabilityEngine.endWindow();
    _holdStartedAt = null;
    _currentHoldSeconds = 0.0;
  }

  void _endHoldForVisibilityLoss() {
    if (_phase != HoldPhase.holding) {
      return;
    }

    _bestHoldSeconds = math.max(_bestHoldSeconds, _currentHoldSeconds);
    _stabilityEngine.endWindow();
    _holdStartedAt = null;
    _currentHoldSeconds = 0.0;
    _misalignmentStartedAt = null;
    _phase = HoldPhase.ready;
  }

  HoldFeedbackCode _currentCorrectiveFeedbackCode() {
    return _lastCorrectiveFeedbackCodeValue;
  }

  @override
  void beginVisibilityGap() {
    if (_visibilityGapWindow.isActive ||
        _phase != HoldPhase.holding ||
        _holdStartedAt == null) {
      return;
    }

    _visibilityGapWindow.begin(_lastVisibleFrameAt ?? _now());
    _misalignmentStartedAt = null;
  }

  @override
  HoldVisibilityResumeResult resumeAfterVisibilityGap() {
    if (!_visibilityGapWindow.isActive) {
      return const HoldVisibilityResumeResult(
        disposition: HoldVisibilityResumeDisposition.noGap,
      );
    }

    final now = _now();
    final isWithinGrace = _visibilityGapWindow.isWithinGraceAt(now);
    final gapDuration = _visibilityGapWindow.consume(now)!;

    // Visibility loss and posture drift are different events. A brief camera
    // gap gets a longer freeze window while hidden time stays excluded.
    if (isWithinGrace &&
        _phase == HoldPhase.holding &&
        _holdStartedAt != null) {
      _holdStartedAt = _holdStartedAt!.add(gapDuration);
      return HoldVisibilityResumeResult(
        disposition: HoldVisibilityResumeDisposition.resumed,
        gapDuration: gapDuration,
      );
    }

    _endHoldForVisibilityLoss();
    return HoldVisibilityResumeResult(
      disposition: HoldVisibilityResumeDisposition.ended,
      gapDuration: gapDuration,
    );
  }

  @override
  void interrupt({String? reason}) {
    if (_phase == HoldPhase.holding) {
      _bestHoldSeconds = math.max(_bestHoldSeconds, _currentHoldSeconds);
      _stabilityEngine.endWindow();
    } else {
      _stabilityEngine.abandonWindow();
    }

    _holdStartedAt = null;
    _currentHoldSeconds = 0.0;
    _misalignmentStartedAt = null;
    _lastVisibleFrameAt = null;
    _visibilityGapWindow.reset();
    _lastVisiblePosture = HoldPostureDiagnosticsSnapshot();
    _lastCorrectiveFeedbackCodeValue = HoldFeedbackCode.correctForm;
    _phase = HoldPhase.ready;
  }

  @override
  void reset() {
    _phase = HoldPhase.ready;
    _holdStartedAt = null;
    _currentHoldSeconds = 0.0;
    _bestHoldSeconds = 0.0;
    _hadFormBreak = false;
    _lastVisiblePosture = HoldPostureDiagnosticsSnapshot();
    _lastCorrectiveFeedbackCodeValue = HoldFeedbackCode.correctForm;
    _lastVisibleFrameAt = null;
    _misalignmentStartedAt = null;
    _visibilityGapWindow.reset();
    _stabilityEngine.reset();
  }
}
