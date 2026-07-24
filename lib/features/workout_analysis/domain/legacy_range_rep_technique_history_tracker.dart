import 'legacy_range_rep_phase_quality_policy.dart';
import 'models/exercise_config.dart';
import 'models/range_rep_confirmed_transition.dart';
import 'models/range_rep_contract.dart';
import 'models/range_rep_engine_frame_result.dart';
import 'models/range_rep_feedback_code.dart';
import 'range_rep_diagnostics.dart';

class LegacyRangeRepCompletedTechniqueData {
  const LegacyRangeRepCompletedTechniqueData({
    required this.worstFormMetric,
    required this.hadFormViolation,
  });

  final double worstFormMetric;
  final bool hadFormViolation;
}

class LegacyRangeRepTechniqueHistorySnapshot {
  const LegacyRangeRepTechniqueHistorySnapshot({
    required this.currentRepWorstFormMetric,
    required this.currentRepHadFormViolation,
    required this.phaseQualityTelemetry,
    required this.descendingPhaseAssessment,
    required this.peakPhaseAssessment,
    required this.ascendingPhaseAssessment,
    required this.phaseFeedbackCandidate,
  });

  final double currentRepWorstFormMetric;
  final bool currentRepHadFormViolation;
  final RangeRepPhaseQualityTelemetry phaseQualityTelemetry;
  final RangeRepPhaseQualityAssessment descendingPhaseAssessment;
  final RangeRepPhaseQualityAssessment peakPhaseAssessment;
  final RangeRepPhaseQualityAssessment ascendingPhaseAssessment;
  final RangeRepFeedbackCode? phaseFeedbackCandidate;
}

class LegacyRangeRepTechniqueHistoryTracker {
  LegacyRangeRepTechniqueHistoryTracker({
    required RangeRepPhaseQualityConfig? phaseQualityConfig,
    LegacyRangeRepPhaseQualityPolicy phaseQualityPolicy =
        const LegacyRangeRepPhaseQualityPolicy(),
  }) : _phaseQualityConfig = phaseQualityConfig,
       _phaseQualityPolicy = phaseQualityPolicy;

  final RangeRepPhaseQualityConfig? _phaseQualityConfig;
  final LegacyRangeRepPhaseQualityPolicy _phaseQualityPolicy;
  final _MutableRangeRepPhaseQuality _descending =
      _MutableRangeRepPhaseQuality();
  final _MutableRangeRepPhaseQuality _peak = _MutableRangeRepPhaseQuality();
  final _MutableRangeRepPhaseQuality _ascending =
      _MutableRangeRepPhaseQuality();

  bool _hasActiveRep = false;
  RangeRepPhase? _activePhase;
  double _currentRepWorstFormMetric = 180.0;
  bool _currentRepHadFormViolation = false;
  RangeRepPhaseQualityTelemetry? _lastCompletedPhaseQualityTelemetry;

  LegacyRangeRepCompletedTechniqueData? recordFrame({
    required RangeRepEngineFrameResult engineResult,
    required double primaryMetric,
    required double formMetric,
    required bool hasTechniqueViolation,
  }) {
    if (engineResult.repStarted) {
      _startRep(
        formMetric: formMetric,
        hasTechniqueViolation: hasTechniqueViolation,
      );
    } else if (engineResult.observedRepPhases.isNotEmpty) {
      _recordRepTechnique(
        formMetric: formMetric,
        hasTechniqueViolation: hasTechniqueViolation,
      );
    }

    if (engineResult.confirmedTransitions.isEmpty) {
      for (final phase in engineResult.observedRepPhases) {
        _recordPhase(
          phase,
          primaryMetric: primaryMetric,
          formMetric: formMetric,
          hasTechniqueViolation: hasTechniqueViolation,
        );
      }
      return null;
    }

    LegacyRangeRepCompletedTechniqueData? completedTechniqueData;
    for (final transition in engineResult.confirmedTransitions) {
      final completed = _recordConfirmedTransition(
        transition,
        primaryMetric: primaryMetric,
        formMetric: formMetric,
        hasTechniqueViolation: hasTechniqueViolation,
      );
      completedTechniqueData = completed ?? completedTechniqueData;
    }
    return completedTechniqueData;
  }

  LegacyRangeRepCompletedTechniqueData? _recordConfirmedTransition(
    RangeRepConfirmedTransition transition, {
    required double primaryMetric,
    required double formMetric,
    required bool hasTechniqueViolation,
  }) {
    switch (transition.type) {
      case RangeRepConfirmedTransitionType.acquireNeutral:
        return null;
      case RangeRepConfirmedTransitionType.startDescending:
        _startPhase(
          RangeRepPhase.descending,
          startedAt: transition.effectiveAt,
          primaryMetric: primaryMetric,
          formMetric: formMetric,
          hasTechniqueViolation: hasTechniqueViolation,
        );
        return null;
      case RangeRepConfirmedTransitionType.reachPeak:
        _recordPhase(
          RangeRepPhase.descending,
          primaryMetric: primaryMetric,
          formMetric: formMetric,
          hasTechniqueViolation: hasTechniqueViolation,
        );
        _completePhase(RangeRepPhase.descending, transition.effectiveAt);
        _startPhase(
          RangeRepPhase.peak,
          startedAt: transition.effectiveAt,
          primaryMetric: primaryMetric,
          formMetric: formMetric,
          hasTechniqueViolation: hasTechniqueViolation,
        );
        return null;
      case RangeRepConfirmedTransitionType.startAscending:
        _recordPhase(
          RangeRepPhase.peak,
          primaryMetric: primaryMetric,
          formMetric: formMetric,
          hasTechniqueViolation: hasTechniqueViolation,
        );
        _completePhase(RangeRepPhase.peak, transition.effectiveAt);
        _startPhase(
          RangeRepPhase.ascending,
          startedAt: transition.effectiveAt,
          primaryMetric: primaryMetric,
          formMetric: formMetric,
          hasTechniqueViolation: hasTechniqueViolation,
        );
        return null;
      case RangeRepConfirmedTransitionType.abortToNeutral:
        _recordPhase(
          RangeRepPhase.descending,
          primaryMetric: primaryMetric,
          formMetric: formMetric,
          hasTechniqueViolation: hasTechniqueViolation,
        );
        clearActiveRepContext();
        return null;
      case RangeRepConfirmedTransitionType.completeRep:
        _recordPhase(
          RangeRepPhase.ascending,
          primaryMetric: primaryMetric,
          formMetric: formMetric,
          hasTechniqueViolation: hasTechniqueViolation,
        );
        _completePhase(RangeRepPhase.ascending, transition.effectiveAt);
        if (!_hasActiveRep) {
          return null;
        }
        final completedTechniqueData = LegacyRangeRepCompletedTechniqueData(
          worstFormMetric: _currentRepWorstFormMetric,
          hadFormViolation: _currentRepHadFormViolation,
        );
        _lastCompletedPhaseQualityTelemetry = _currentTelemetry(
          now: transition.effectiveAt,
          activePhase: null,
        );
        _hasActiveRep = false;
        _activePhase = null;
        return completedTechniqueData;
    }
  }

  void shiftActivePhaseTiming(Duration gapDuration) {
    final activePhase = _activePhase;
    if (activePhase == null || gapDuration <= Duration.zero) {
      return;
    }
    _phaseQualityFor(activePhase).shiftStartedAt(gapDuration);
  }

  void clearActiveRepContext() {
    _hasActiveRep = false;
    _activePhase = null;
    _currentRepWorstFormMetric = 180.0;
    _currentRepHadFormViolation = false;
    _resetPhaseQuality();
  }

  LegacyRangeRepTechniqueHistorySnapshot snapshot({
    required DateTime now,
    required bool preferLastCompletedTelemetry,
  }) {
    final useLastCompleted =
        preferLastCompletedTelemetry &&
        _lastCompletedPhaseQualityTelemetry != null;
    final telemetry = useLastCompleted
        ? _lastCompletedPhaseQualityTelemetry!
        : _currentTelemetry(now: now, activePhase: _activePhase);
    final assessedActivePhase = useLastCompleted ? null : _activePhase;
    final descendingAssessment = _phaseQualityPolicy.assess(
      phase: RangeRepPhase.descending,
      phaseQuality: telemetry.descendingPhaseQuality,
      isActivePhase: assessedActivePhase == RangeRepPhase.descending,
      config: _phaseQualityConfig,
    );
    final peakAssessment = _phaseQualityPolicy.assess(
      phase: RangeRepPhase.peak,
      phaseQuality: telemetry.peakPhaseQuality,
      isActivePhase: assessedActivePhase == RangeRepPhase.peak,
      config: _phaseQualityConfig,
    );
    final ascendingAssessment = _phaseQualityPolicy.assess(
      phase: RangeRepPhase.ascending,
      phaseQuality: telemetry.ascendingPhaseQuality,
      isActivePhase: assessedActivePhase == RangeRepPhase.ascending,
      config: _phaseQualityConfig,
    );

    return LegacyRangeRepTechniqueHistorySnapshot(
      currentRepWorstFormMetric: _currentRepWorstFormMetric,
      currentRepHadFormViolation: _currentRepHadFormViolation,
      phaseQualityTelemetry: telemetry,
      descendingPhaseAssessment: descendingAssessment,
      peakPhaseAssessment: peakAssessment,
      ascendingPhaseAssessment: ascendingAssessment,
      phaseFeedbackCandidate: _phaseQualityPolicy.feedbackCandidate(
        descending: descendingAssessment,
        peak: peakAssessment,
        ascending: ascendingAssessment,
      ),
    );
  }

  void _startRep({
    required double formMetric,
    required bool hasTechniqueViolation,
  }) {
    _hasActiveRep = true;
    _currentRepWorstFormMetric = formMetric;
    _currentRepHadFormViolation = hasTechniqueViolation;
    _resetPhaseQuality();
  }

  void _recordRepTechnique({
    required double formMetric,
    required bool hasTechniqueViolation,
  }) {
    if (!_hasActiveRep) {
      return;
    }
    if (formMetric < _currentRepWorstFormMetric) {
      _currentRepWorstFormMetric = formMetric;
    }
    if (hasTechniqueViolation) {
      _currentRepHadFormViolation = true;
    }
  }

  void _startPhase(
    RangeRepPhase phase, {
    required DateTime startedAt,
    required double primaryMetric,
    required double formMetric,
    required bool hasTechniqueViolation,
  }) {
    if (!_hasActiveRep) {
      return;
    }
    _activePhase = phase;
    _phaseQualityFor(phase).start(
      startedAt: startedAt,
      primaryMetric: primaryMetric,
      formMetric: formMetric,
      hadFormViolation: hasTechniqueViolation,
    );
  }

  void _recordPhase(
    RangeRepPhase phase, {
    required double primaryMetric,
    required double formMetric,
    required bool hasTechniqueViolation,
  }) {
    if (!_hasActiveRep) {
      return;
    }
    _phaseQualityFor(phase).record(
      primaryMetric: primaryMetric,
      formMetric: formMetric,
      hadFormViolation: hasTechniqueViolation,
    );
  }

  void _completePhase(RangeRepPhase phase, DateTime endedAt) {
    if (!_hasActiveRep) {
      return;
    }
    _phaseQualityFor(phase).complete(endedAt);
  }

  RangeRepPhaseQualityTelemetry _currentTelemetry({
    required DateTime now,
    required RangeRepPhase? activePhase,
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

  _MutableRangeRepPhaseQuality _phaseQualityFor(RangeRepPhase phase) {
    return switch (phase) {
      RangeRepPhase.descending => _descending,
      RangeRepPhase.peak => _peak,
      RangeRepPhase.ascending => _ascending,
    };
  }

  void _resetPhaseQuality() {
    _descending.reset();
    _peak.reset();
    _ascending.reset();
  }
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
        : (_minPrimaryMetric! < primaryMetric
              ? _minPrimaryMetric
              : primaryMetric);
    _maxPrimaryMetric = _maxPrimaryMetric == null
        ? primaryMetric
        : (_maxPrimaryMetric! > primaryMetric
              ? _maxPrimaryMetric
              : primaryMetric);
    _worstFormMetric = _worstFormMetric == null
        ? formMetric
        : (_worstFormMetric! < formMetric ? _worstFormMetric : formMetric);
    _hadFormViolation = _hadFormViolation || hadFormViolation;
  }

  void complete(DateTime endedAt) {
    final startedAt = _startedAt;
    if (startedAt == null) {
      return;
    }
    final durationMs = endedAt.difference(startedAt).inMilliseconds;
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
