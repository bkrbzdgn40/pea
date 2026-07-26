import '../../domain/models/setup_readiness_state.dart';

/// User-visible phase of the one-tap preparation start gate.
enum PreparationStartGatePhase {
  idle,
  monitoring,
  overrideAvailable,
  countingDown,
  approved,
  launching,
}

/// Evidence source that approved the transition to live analysis.
enum PreparationStartApprovalSource { readiness, manualOverride }

/// Timing thresholds for the preparation start gate.
class PreparationStartGateThresholds {
  factory PreparationStartGateThresholds({
    required Duration manualOverrideDelay,
    Duration countdownStepDuration = const Duration(seconds: 1),
    int countdownFrom = 3,
  }) {
    assert(!manualOverrideDelay.isNegative);
    assert(countdownStepDuration.compareTo(Duration.zero) > 0);
    assert(countdownFrom > 0);
    return PreparationStartGateThresholds._(
      manualOverrideDelay: manualOverrideDelay,
      countdownStepDuration: countdownStepDuration,
      countdownFrom: countdownFrom,
    );
  }

  const PreparationStartGateThresholds._({
    required this.manualOverrideDelay,
    required this.countdownStepDuration,
    required this.countdownFrom,
  });

  static const PreparationStartGateThresholds defaults =
      PreparationStartGateThresholds._(
        manualOverrideDelay: Duration(seconds: 10),
        countdownStepDuration: Duration(seconds: 1),
        countdownFrom: 3,
      );

  final Duration manualOverrideDelay;
  final Duration countdownStepDuration;
  final int countdownFrom;
}

/// Immutable state exposed to the preparation start controls.
class PreparationStartGateState {
  const PreparationStartGateState({
    required this.phase,
    required this.readinessSnapshot,
    this.armedAt,
    this.countdownStartedAt,
    this.approvedAt,
    this.approvalSource,
    this.countdownValue,
  });

  factory PreparationStartGateState.idle({
    required SetupReadinessSnapshot readinessSnapshot,
  }) {
    return PreparationStartGateState(
      phase: PreparationStartGatePhase.idle,
      readinessSnapshot: readinessSnapshot,
    );
  }

  final PreparationStartGatePhase phase;
  final SetupReadinessSnapshot readinessSnapshot;
  final DateTime? armedAt;
  final DateTime? countdownStartedAt;
  final DateTime? approvedAt;
  final PreparationStartApprovalSource? approvalSource;
  final int? countdownValue;

  bool get isArmed =>
      phase == PreparationStartGatePhase.monitoring ||
      phase == PreparationStartGatePhase.overrideAvailable ||
      phase == PreparationStartGatePhase.countingDown;

  bool get canCancel => isArmed;

  bool get canOverride => phase == PreparationStartGatePhase.overrideAvailable;

  bool get isCountingDown =>
      phase == PreparationStartGatePhase.countingDown && countdownValue != null;

  bool get isApproved => phase == PreparationStartGatePhase.approved;

  bool get isLaunching => phase == PreparationStartGatePhase.launching;
}
