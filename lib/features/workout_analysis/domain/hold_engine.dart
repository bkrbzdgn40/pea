import 'dart:math' as math;

import 'analysis_visibility_gap_window.dart';
import 'hold_analysis_engine.dart';
import 'hold_diagnostics.dart';
import 'hold_posture_policy.dart';
import 'models/analysis_frame.dart';
import 'models/exercise_config.dart';
import 'models/hold_feedback_code.dart';
import 'models/hold_phase.dart';

/// First real non-repetition engine family backed by typed hold diagnostics.
class HoldEngine implements HoldAnalysisEngine {
  HoldEngine({required this.config, DateTime Function()? now})
    : _now = now ?? DateTime.now,
      _posturePolicy = HoldPosturePolicy(config: config.resolvedHoldPosture);

  final ExerciseConfig config;
  final DateTime Function() _now;
  final HoldPosturePolicy _posturePolicy;

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
      const HoldPostureDiagnosticsSnapshot();

  @override
  HoldFeedbackCode get feedbackCode {
    switch (_phase) {
      case HoldPhase.ready:
        return HoldFeedbackCode.preparePosition;
      case HoldPhase.holding:
        if (_misalignmentStartedAt != null) {
          return _alignmentFeedbackCode();
        }
        return HoldFeedbackCode.holdPosition;
      case HoldPhase.broken:
        return _alignmentFeedbackCode();
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
    bodyLineTargetAngle: _posturePolicy.bodyLineTargetAngle(
      isHolding: _phase == HoldPhase.holding,
    ),
    phase: _phase,
    feedbackCode: feedbackCode,
    lastVisiblePosture: _lastVisiblePosture,
    isFormBreakGraceActive: _misalignmentStartedAt != null,
  );

  @override
  void update(AnalysisFrame frame) {
    final now = _now();
    _lastVisibleFrameAt = now;
    final evaluation = _posturePolicy.evaluate(
      bodyLineAngle: frame.bodyLineAngle,
      armSupportAngle: frame.armSupportAngle,
      legExtensionAngle: frame.legExtensionAngle,
      isHolding: _phase == HoldPhase.holding,
    );
    _lastVisiblePosture = HoldPostureDiagnosticsSnapshot(
      hasCompleteMetrics: evaluation.hasCompleteMetrics,
      hasActivePosture: evaluation.hasActivePosture,
      isBodyAligned: evaluation.isBodyAligned,
      isArmSupported: evaluation.isArmSupported,
      areLegsExtended: evaluation.areLegsExtended,
    );

    if (evaluation.isValidHoldPosture) {
      _misalignmentStartedAt = null;
      _startOrContinueHold(now);
      return;
    }

    if (_phase == HoldPhase.holding && evaluation.supportsGraceWindow) {
      _misalignmentStartedAt ??= now;
      if (now.difference(_misalignmentStartedAt!) <
          _posturePolicy.config.breakGraceDuration) {
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

  void _startOrContinueHold(DateTime now) {
    if (_phase != HoldPhase.holding || _holdStartedAt == null) {
      _holdStartedAt = now;
      _currentHoldSeconds = 0.0;
      _hadFormBreak = false;
    } else {
      _currentHoldSeconds =
          now.difference(_holdStartedAt!).inMilliseconds / 1000.0;
    }

    _phase = HoldPhase.holding;
    _bestHoldSeconds = math.max(_bestHoldSeconds, _currentHoldSeconds);
  }

  void _stopActiveHoldIfNeeded() {
    if (_phase != HoldPhase.holding) {
      return;
    }

    _bestHoldSeconds = math.max(_bestHoldSeconds, _currentHoldSeconds);
    _holdStartedAt = null;
    _currentHoldSeconds = 0.0;
  }

  void _endHoldForVisibilityLoss() {
    if (_phase != HoldPhase.holding) {
      return;
    }

    _bestHoldSeconds = math.max(_bestHoldSeconds, _currentHoldSeconds);
    _holdStartedAt = null;
    _currentHoldSeconds = 0.0;
    _misalignmentStartedAt = null;
    _phase = HoldPhase.ready;
  }

  HoldFeedbackCode _alignmentFeedbackCode() {
    if (!_lastVisiblePosture.isBodyAligned) {
      return HoldFeedbackCode.alignHips;
    }
    if (!_lastVisiblePosture.isArmSupported) {
      return HoldFeedbackCode.adjustElbowSupport;
    }
    if (!_lastVisiblePosture.areLegsExtended) {
      return HoldFeedbackCode.extendLegs;
    }
    return HoldFeedbackCode.correctForm;
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
      return const HoldVisibilityResumeResult(
        disposition: HoldVisibilityResumeDisposition.resumed,
      );
    }

    _endHoldForVisibilityLoss();
    return const HoldVisibilityResumeResult(
      disposition: HoldVisibilityResumeDisposition.ended,
    );
  }

  @override
  void interrupt({String? reason}) {
    if (_phase == HoldPhase.holding) {
      _bestHoldSeconds = math.max(_bestHoldSeconds, _currentHoldSeconds);
    }

    _holdStartedAt = null;
    _currentHoldSeconds = 0.0;
    _misalignmentStartedAt = null;
    _lastVisibleFrameAt = null;
    _visibilityGapWindow.reset();
    _lastVisiblePosture = const HoldPostureDiagnosticsSnapshot();
    _phase = HoldPhase.ready;
  }

  @override
  void reset() {
    _phase = HoldPhase.ready;
    _holdStartedAt = null;
    _currentHoldSeconds = 0.0;
    _bestHoldSeconds = 0.0;
    _hadFormBreak = false;
    _lastVisiblePosture = const HoldPostureDiagnosticsSnapshot();
    _lastVisibleFrameAt = null;
    _misalignmentStartedAt = null;
    _visibilityGapWindow.reset();
  }
}
