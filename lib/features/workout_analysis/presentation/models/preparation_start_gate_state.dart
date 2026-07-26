import '../../domain/models/setup_readiness_state.dart';

/// User-visible phase of the one-tap preparation start gate.
enum PreparationStartGatePhase {
  idle,
  monitoring,
  overrideAvailable,
  approved,
  launching,
}

/// Evidence source that approved the transition to live analysis.
enum PreparationStartApprovalSource { readiness, manualOverride }

/// Timing thresholds for the preparation start gate.
class PreparationStartGateThresholds {
  factory PreparationStartGateThresholds({
    required Duration manualOverrideDelay,
  }) {
    assert(!manualOverrideDelay.isNegative);
    return PreparationStartGateThresholds._(
      manualOverrideDelay: manualOverrideDelay,
    );
  }

  const PreparationStartGateThresholds._({required this.manualOverrideDelay});

  static const PreparationStartGateThresholds defaults =
      PreparationStartGateThresholds._(
        manualOverrideDelay: Duration(seconds: 10),
      );

  final Duration manualOverrideDelay;
}

/// Immutable state exposed to the preparation start controls.
class PreparationStartGateState {
  const PreparationStartGateState({
    required this.phase,
    required this.readinessSnapshot,
    this.armedAt,
    this.approvedAt,
    this.approvalSource,
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
  final DateTime? approvedAt;
  final PreparationStartApprovalSource? approvalSource;

  bool get isArmed =>
      phase == PreparationStartGatePhase.monitoring ||
      phase == PreparationStartGatePhase.overrideAvailable;

  bool get canCancel => isArmed;

  bool get canOverride => phase == PreparationStartGatePhase.overrideAvailable;

  bool get isApproved => phase == PreparationStartGatePhase.approved;

  bool get isLaunching => phase == PreparationStartGatePhase.launching;
}
