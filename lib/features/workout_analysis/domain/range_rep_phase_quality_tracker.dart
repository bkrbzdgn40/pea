import 'legacy_range_rep_phase_quality_policy.dart';
import 'models/exercise_config.dart';
import 'models/range_rep_contract.dart';
import 'models/range_rep_feedback_code.dart';
import 'range_rep_diagnostics.dart';

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

  void shiftStartedAt(Duration delta) {
    if (_startedAt == null || delta == Duration.zero) {
      return;
    }
    _startedAt = _startedAt!.add(delta);
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

/// Owns mutable phase-quality samples and their legacy assessments.
class RangeRepPhaseQualityTracker {
  RangeRepPhaseQualityTracker({
    required this.config,
    LegacyRangeRepPhaseQualityPolicy policy =
        const LegacyRangeRepPhaseQualityPolicy(),
  }) : _policy = policy;

  final ExerciseConfig config;
  final LegacyRangeRepPhaseQualityPolicy _policy;
  final _MutableRangeRepPhaseQuality _descending =
      _MutableRangeRepPhaseQuality();
  final _MutableRangeRepPhaseQuality _peak = _MutableRangeRepPhaseQuality();
  final _MutableRangeRepPhaseQuality _ascending =
      _MutableRangeRepPhaseQuality();

  RangeRepPhaseQualityTelemetry? lastCompletedTelemetry;

  void start({
    required RangeRepPhase phase,
    required DateTime startedAt,
    required double primaryMetric,
    required double formMetric,
    required bool hadFormViolation,
  }) {
    _qualityFor(phase).start(
      startedAt: startedAt,
      primaryMetric: primaryMetric,
      formMetric: formMetric,
      hadFormViolation: hadFormViolation,
    );
  }

  void record({
    required RangeRepPhase phase,
    required double primaryMetric,
    required double formMetric,
    required bool hadFormViolation,
  }) {
    _qualityFor(phase).record(
      primaryMetric: primaryMetric,
      formMetric: formMetric,
      hadFormViolation: hadFormViolation,
    );
  }

  void complete({required RangeRepPhase phase, required DateTime endedAt}) {
    _qualityFor(phase).complete(endedAt);
  }

  void shiftStartedAt({required RangeRepPhase phase, required Duration delta}) {
    _qualityFor(phase).shiftStartedAt(delta);
  }

  RangeRepPhaseQualityTelemetry telemetry({
    required DateTime now,
    RangeRepPhase? activePhase,
  }) {
    return RangeRepPhaseQualityTelemetry(
      descendingPhaseQuality: _descending.snapshot(
        now: now,
        isActive: activePhase == RangeRepPhase.descending,
      ),
      peakPhaseQuality: _peak.snapshot(
        now: now,
        isActive: activePhase == RangeRepPhase.peak,
      ),
      ascendingPhaseQuality: _ascending.snapshot(
        now: now,
        isActive: activePhase == RangeRepPhase.ascending,
      ),
    );
  }

  RangeRepPhaseQualityTelemetry completedTelemetry(DateTime capturedAt) {
    return telemetry(now: capturedAt);
  }

  void captureCompleted(DateTime capturedAt) {
    lastCompletedTelemetry = completedTelemetry(capturedAt);
  }

  RangeRepPhaseQualityAssessment assess({
    required RangeRepPhase phase,
    required RangeRepPhaseQualitySnapshot phaseQuality,
    required bool isActivePhase,
  }) {
    return _policy.assess(
      phase: phase,
      phaseQuality: phaseQuality,
      isActivePhase: isActivePhase,
      config: config.rangeRepPhaseQuality,
    );
  }

  RangeRepFeedbackCode? feedbackCandidate({
    required RangeRepPhaseQualityAssessment descending,
    required RangeRepPhaseQualityAssessment peak,
    required RangeRepPhaseQualityAssessment ascending,
  }) {
    return _policy.feedbackCandidate(
      descending: descending,
      peak: peak,
      ascending: ascending,
    );
  }

  void reset() {
    _descending.reset();
    _peak.reset();
    _ascending.reset();
  }

  void resetAll() {
    reset();
    lastCompletedTelemetry = null;
  }

  _MutableRangeRepPhaseQuality _qualityFor(RangeRepPhase phase) {
    return switch (phase) {
      RangeRepPhase.descending => _descending,
      RangeRepPhase.peak => _peak,
      RangeRepPhase.ascending => _ascending,
    };
  }
}
