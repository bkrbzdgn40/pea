enum RangeRepConfirmedTransitionType {
  acquireNeutral,
  startDescending,
  reachPeak,
  startAscending,
  abortToNeutral,
  completeRep,
}

class RangeRepConfirmedTransition {
  const RangeRepConfirmedTransition({
    required this.type,
    required this.effectiveAt,
    DateTime? confirmedAt,
  }) : confirmedAt = confirmedAt ?? effectiveAt;

  final RangeRepConfirmedTransitionType type;

  /// First observation at which the transition condition became true.
  final DateTime effectiveAt;

  /// Observation that completed the configured confirmation window.
  final DateTime confirmedAt;
}
