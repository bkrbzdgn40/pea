enum LiveTrackingPhase {
  tracking,
  temporarilyLost,
  repositionRequired,
  reacquiring,
}

class LiveTrackingState {
  const LiveTrackingState({
    required this.phase,
    this.lossStartedAt,
    this.lastTransitionAt,
  });

  const LiveTrackingState.tracking()
    : phase = LiveTrackingPhase.tracking,
      lossStartedAt = null,
      lastTransitionAt = null;

  final LiveTrackingPhase phase;
  final DateTime? lossStartedAt;
  final DateTime? lastTransitionAt;

  bool get isTracking => phase == LiveTrackingPhase.tracking;
  bool get suppressesExerciseFeedback => !isTracking;
  bool get showsRecoveryOverlay => !isTracking;

  LiveTrackingState copyWith({
    LiveTrackingPhase? phase,
    Object? lossStartedAt = _unset,
    Object? lastTransitionAt = _unset,
  }) {
    return LiveTrackingState(
      phase: phase ?? this.phase,
      lossStartedAt: identical(lossStartedAt, _unset)
          ? this.lossStartedAt
          : lossStartedAt as DateTime?,
      lastTransitionAt: identical(lastTransitionAt, _unset)
          ? this.lastTransitionAt
          : lastTransitionAt as DateTime?,
    );
  }

  static const Object _unset = Object();
}
