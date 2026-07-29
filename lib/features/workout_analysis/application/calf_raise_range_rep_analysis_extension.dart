import '../domain/range_rep_diagnostics.dart';
import 'calf_raise_movement_evidence.dart';
import 'exercise_metrics.dart';
import 'range_rep_exercise_analysis_extension.dart';
import 'range_rep_noop_analysis_extension.dart';

/// Prevents ankle-angle false positives from entering the generic Calf Raise
/// lifecycle.
///
/// The adapter runs after quality filtering and side selection. It therefore
/// evaluates the same selected-side frame that the engine will consume, rather
/// than maintaining a second raw-frame interpretation of the movement.
class CalfRaiseRangeRepAnalysisExtension
    extends NoOpRangeRepExerciseAnalysisExtension
    implements RangeRepDetectionFrameAdapter {
  CalfRaiseRangeRepAnalysisExtension({
    CalfRaiseMovementEvidencePolicy evidencePolicy =
        const CalfRaiseMovementEvidencePolicy(),
  }) : _evidencePolicy = evidencePolicy;

  static const int _minimumNeutralSampleCount = 2;
  static const int _maximumNeutralSampleCount = 9;

  final CalfRaiseMovementEvidencePolicy _evidencePolicy;
  final Map<RangeRepSide, List<CalfRaisePoseSample>> _neutralSamples =
      <RangeRepSide, List<CalfRaisePoseSample>>{};
  final Map<RangeRepSide, CalfRaisePoseSample> _neutralBaselines =
      <RangeRepSide, CalfRaisePoseSample>{};

  final Map<RangeRepSide, DateTime> _lastNeutralSampleAt =
      <RangeRepSide, DateTime>{};

  @override
  double adaptPrimaryMetric(RangeRepDetectionFrameContext context) {
    final sideMetrics = _metricsForSide(context.metrics, context.selectedSide);
    final current = _evidencePolicy.measure(
      context.metrics,
      context.selectedSide,
    );
    if (_isNeutralCalibrationFrame(context, sideMetrics) && current != null) {
      _recordNeutralSample(context.selectedSide, current, context.now);
    }

    return _adaptCurrentFrame(context: context, current: current);
  }

  double _adaptCurrentFrame({
    required RangeRepDetectionFrameContext context,
    required CalfRaisePoseSample? current,
  }) {
    if (context.primaryMetric <= context.activeThreshold) {
      return context.primaryMetric;
    }

    // Once PEAK has been confirmed, the engine must see the natural return to
    // neutral. Movement identity is established on the way toward PEAK.
    if (context.currentPhase == 'PEAK' || context.currentPhase == 'ASCENDING') {
      return context.primaryMetric;
    }

    final evidence = _evidencePolicy.evaluate(
      baseline: _neutralBaselines[context.selectedSide],
      current: current,
    );
    return evidence.isCalfRaise
        ? context.primaryMetric
        : context.activeThreshold;
  }

  bool _isNeutralCalibrationFrame(
    RangeRepDetectionFrameContext context,
    RangeRepSideMetrics sideMetrics,
  ) {
    final phase = context.currentPhase;
    final isNeutralPhase =
        phase == rangeRepAwaitNeutralPhaseLabel || phase == 'NEUTRAL';
    return isNeutralPhase &&
        !context.hasActiveRepContext &&
        sideMetrics.hasPrimaryAngle &&
        context.primaryMetric <= context.neutralThreshold;
  }

  void _recordNeutralSample(
    RangeRepSide side,
    CalfRaisePoseSample sample,
    DateTime now,
  ) {
    if (_lastNeutralSampleAt[side] == now) {
      return;
    }
    _lastNeutralSampleAt[side] = now;

    final samples = _neutralSamples.putIfAbsent(
      side,
      () => <CalfRaisePoseSample>[],
    );
    samples.add(sample);
    if (samples.length > _maximumNeutralSampleCount) {
      samples.removeAt(0);
    }
    if (samples.length >= _minimumNeutralSampleCount) {
      _neutralBaselines[side] = _evidencePolicy.medianSample(samples);
    }
  }

  RangeRepSideMetrics _metricsForSide(
    ExerciseMetrics metrics,
    RangeRepSide side,
  ) {
    return switch (side) {
      RangeRepSide.left => metrics.leftRangeRepMetrics,
      RangeRepSide.right => metrics.rightRangeRepMetrics,
    };
  }

  @override
  void reset() {
    _neutralSamples.clear();
    _neutralBaselines.clear();
    _lastNeutralSampleAt.clear();
  }
}
