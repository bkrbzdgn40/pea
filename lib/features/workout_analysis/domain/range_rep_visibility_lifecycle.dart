import 'analysis_visibility_gap_window.dart';
import 'generic_rep_engine.dart';
import 'range_rep_diagnostics.dart';

/// Owns the short visibility-gap window and frozen phase facts.
class RangeRepVisibilityLifecycle {
  RangeRepVisibilityLifecycle({
    required Duration graceDuration,
    required DateTime Function() now,
  }) : _window = AnalysisVisibilityGapWindow(graceDuration: graceDuration),
       _now = now;

  final AnalysisVisibilityGapWindow _window;
  final DateTime Function() _now;

  GenericRepPhase? _frozenPhase;
  bool _wasArmed = false;

  void begin({
    required GenericRepEngine engine,
    DateTime? observedAt,
    required void Function() onGapStarted,
  }) {
    if (_window.isActive) {
      return;
    }

    onGapStarted();
    _window.begin(observedAt ?? _now());
    _frozenPhase = engine.phase;
    _wasArmed = engine.isArmed;
    engine.cancelPendingTransition();
  }

  VisibilityGapResumeResult resume({
    required GenericRepEngine engine,
    required double primaryMetric,
    DateTime? observedAt,
    required void Function(Duration gapDuration) onCompatibleGap,
  }) {
    if (!_window.isActive) {
      return const VisibilityGapResumeResult(
        disposition: VisibilityGapResumeDisposition.noGap,
      );
    }

    final frozenPhase = _frozenPhase ?? engine.phase;
    final isCompatible = engine.isMetricCompatibleWithPhase(
      primaryMetric,
      frozenPhase: frozenPhase,
      wasArmed: _wasArmed,
    );
    if (!isCompatible) {
      reset();
      return const VisibilityGapResumeResult(
        disposition: VisibilityGapResumeDisposition.incompatible,
        reason: 'phase incompatible recovery',
      );
    }

    final gapDuration = _window.consume(observedAt ?? _now())!;
    onCompatibleGap(gapDuration);
    _frozenPhase = null;
    _wasArmed = false;

    return VisibilityGapResumeResult(
      disposition: VisibilityGapResumeDisposition.compatible,
      appliedGapDuration: gapDuration,
    );
  }

  void reset() {
    _window.reset();
    _frozenPhase = null;
    _wasArmed = false;
  }
}
