import 'dart:math' as math;

import 'analysis_engine.dart';
import 'hold_diagnostics.dart';
import 'hold_posture_policy.dart';
import 'models/analysis_frame.dart';
import 'models/exercise_config.dart';
import 'models/hold_feedback_code.dart';
import 'models/hold_phase.dart';

/// First real non-repetition engine family.
///
/// The shared contract still carries rep-oriented fields, so this engine keeps
/// those values at safe placeholders while exposing meaningful hold telemetry
/// through its own diagnostics surface.
class HoldEngine
    implements
        AnalysisEngine,
        HoldFeedbackSource,
        HoldDiagnostics,
        HoldVisibilityGapControl,
        HoldInterruptionControl {
  HoldEngine({required this.config, DateTime Function()? now})
    : _now = now ?? DateTime.now,
      _posturePolicy = HoldPosturePolicy(config: config.resolvedHoldPosture);

  static const Duration _visibilityGapGraceDuration = Duration(
    milliseconds: 1200,
  );

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
  DateTime? _visibilityGapStartedAt;
  HoldPostureDiagnosticsSnapshot _lastVisiblePosture =
      const HoldPostureDiagnosticsSnapshot();

  @override
  int get repCount => 0;

  @override
  bool get isFormBad => _phase == HoldPhase.broken;

  @override
  double get lastRepScore => 0.0;

  @override
  double get maxRom => 0.0;

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

  @override
  String get feedback => feedbackCode.code;

  @override
  String get phaseLabel => _phase.legacyLabel;

  @override
  HoldDiagnosticsSnapshot get diagnosticsSnapshot => HoldDiagnosticsSnapshot(
    currentHoldSeconds: _currentHoldSeconds,
    bestHoldSeconds: _bestHoldSeconds,
    isHolding: _phase == HoldPhase.holding,
    isVisibilitySuspended: _visibilityGapStartedAt != null,
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
    if (_visibilityGapStartedAt != null ||
        _phase != HoldPhase.holding ||
        _holdStartedAt == null) {
      return;
    }

    _visibilityGapStartedAt = _lastVisibleFrameAt ?? _now();
    _misalignmentStartedAt = null;
  }

  @override
  HoldVisibilityResumeResult resumeAfterVisibilityGap() {
    if (_visibilityGapStartedAt == null) {
      return const HoldVisibilityResumeResult(
        disposition: HoldVisibilityResumeDisposition.noGap,
      );
    }

    final gapStartedAt = _visibilityGapStartedAt!;
    _visibilityGapStartedAt = null;
    final gapDuration = _now().difference(gapStartedAt);

    // Visibility loss and posture drift are different events. A brief camera
    // gap gets a longer freeze window while hidden time stays excluded.
    if (gapDuration < _visibilityGapGraceDuration &&
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
  void endActiveHoldForInterruption() {
    if (_phase == HoldPhase.holding) {
      _bestHoldSeconds = math.max(_bestHoldSeconds, _currentHoldSeconds);
    }

    _holdStartedAt = null;
    _currentHoldSeconds = 0.0;
    _misalignmentStartedAt = null;
    _lastVisibleFrameAt = null;
    _visibilityGapStartedAt = null;
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
    _visibilityGapStartedAt = null;
  }
}
