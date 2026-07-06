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
  HoldEngine({required this.config});

  final ExerciseConfig config;

  HoldPhase _phase = HoldPhase.ready;
  DateTime? _holdStartedAt;
  double _currentHoldSeconds = 0.0;
  double _bestHoldSeconds = 0.0;
  bool _hadFormBreak = false;

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
        return 'Formu Duzelt';
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
    final isActivePosture = primaryMetric >= config.thresholdActive;
    final isFormAligned = formMetric >= config.formThreshold;

    if (isActivePosture && isFormAligned) {
      _startOrContinueHold(now);
      return;
    }

    if (_phase == HoldPhase.holding) {
      _bestHoldSeconds = math.max(_bestHoldSeconds, _currentHoldSeconds);
      _holdStartedAt = null;
      _currentHoldSeconds = 0.0;
    }

    if (isActivePosture && !isFormAligned) {
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

  @override
  void reset() {
    _phase = HoldPhase.ready;
    _holdStartedAt = null;
    _currentHoldSeconds = 0.0;
    _bestHoldSeconds = 0.0;
    _hadFormBreak = false;
  }
}
