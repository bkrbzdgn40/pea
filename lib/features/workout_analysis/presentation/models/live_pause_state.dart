import '../../domain/models/setup_readiness_state.dart';

/// User-controlled live-analysis pause and safe resume phases.
enum LivePausePhase { active, paused, resumeMonitoring, resumeCountingDown }

/// Timing policy for the resume countdown.
class LivePauseThresholds {
  const LivePauseThresholds._({
    required this.countdownFrom,
    required this.countdownStepDuration,
  });

  factory LivePauseThresholds({
    required int countdownFrom,
    required Duration countdownStepDuration,
  }) {
    assert(countdownFrom > 0);
    assert(countdownStepDuration > Duration.zero);
    return LivePauseThresholds._(
      countdownFrom: countdownFrom,
      countdownStepDuration: countdownStepDuration,
    );
  }

  static const LivePauseThresholds defaults = LivePauseThresholds._(
    countdownFrom: 3,
    countdownStepDuration: Duration(seconds: 1),
  );

  final int countdownFrom;
  final Duration countdownStepDuration;
}

/// Immutable state for manual pause and readiness-gated resume.
class LivePauseState {
  const LivePauseState({
    required this.phase,
    this.readinessSnapshot,
    this.countdownValue,
  });

  const LivePauseState.active({SetupReadinessSnapshot? readinessSnapshot})
    : this(phase: LivePausePhase.active, readinessSnapshot: readinessSnapshot);

  final LivePausePhase phase;
  final SetupReadinessSnapshot? readinessSnapshot;
  final int? countdownValue;

  bool get isActive => phase == LivePausePhase.active;
  bool get isPaused => phase != LivePausePhase.active;
  bool get isMonitoring => phase == LivePausePhase.resumeMonitoring;
  bool get isCountingDown => phase == LivePausePhase.resumeCountingDown;
}
