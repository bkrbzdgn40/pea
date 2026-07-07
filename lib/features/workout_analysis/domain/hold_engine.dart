import 'dart:math' as math;

import 'analysis_engine.dart';
import 'hold_diagnostics.dart';
import 'models/exercise_config.dart';

enum HoldPhase { ready, holding, broken }

/// First real non-repetition engine family.
///
/// The shared contract still carries rep-oriented fields, so this engine keeps
/// those values at safe placeholders while exposing meaningful hold telemetry
/// through its own diagnostics surface.
class HoldEngine implements AnalysisEngine, HoldDiagnostics {
  static const double _armSupportMinAngle = 60.0;
  static const double _armSupportMaxAngle = 120.0;

  HoldEngine({required this.config});

  final ExerciseConfig config;

  HoldPhase _phase = HoldPhase.ready;
  DateTime? _holdStartedAt;
  double _currentHoldSeconds = 0.0;
  double _bestHoldSeconds = 0.0;
  bool _hadFormBreak = false;
  bool _isBodyAligned = false;
  bool _isArmSupported = false;

  @override
  int get repCount => 0;

  @override
  bool get isFormBad => _phase == HoldPhase.broken;

  @override
  double get lastRepScore => 0.0;

  @override
  double get maxRom => 0.0;

  @override
  String get feedback {
    switch (_phase) {
      case HoldPhase.ready:
        return 'Pozisyonu Hazirla';
      case HoldPhase.holding:
        return 'Pozisyonu Koru';
      case HoldPhase.broken:
        if (!_isBodyAligned && !_isArmSupported) {
          return 'Formu Duzelt';
        }
        if (!_isBodyAligned) {
          return 'Govde Hattini Duzelt';
        }
        return 'Kol Destegini Duzelt';
    }
  }

  @override
  String get phaseLabel => _phase.name.toUpperCase();

  @override
  HoldDiagnosticsSnapshot get diagnosticsSnapshot => HoldDiagnosticsSnapshot(
    currentHoldSeconds: _currentHoldSeconds,
    bestHoldSeconds: _bestHoldSeconds,
    isHolding: _phase == HoldPhase.holding,
    hadFormBreak: _hadFormBreak,
  );

  @override
  void update(double primaryMetric, double formMetric) {
    final now = DateTime.now();
    final hasActivePosture = primaryMetric >= config.thresholdNeutral;
    final isBodyAligned = primaryMetric >= config.thresholdActive;
    final isArmSupported = _isArmSupportAligned(formMetric);

    _isBodyAligned = isBodyAligned;
    _isArmSupported = isArmSupported;

    if (isBodyAligned && isArmSupported) {
      _startOrContinueHold(now);
      return;
    }

    _stopActiveHoldIfNeeded();

    if (hasActivePosture) {
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

  bool _isArmSupportAligned(double angle) {
    // Initial plank heuristic: forearm support should stay near a right angle.
    return angle >= _armSupportMinAngle && angle <= _armSupportMaxAngle;
  }

  @override
  void reset() {
    _phase = HoldPhase.ready;
    _holdStartedAt = null;
    _currentHoldSeconds = 0.0;
    _bestHoldSeconds = 0.0;
    _hadFormBreak = false;
    _isBodyAligned = false;
    _isArmSupported = false;
  }
}
