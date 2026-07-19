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
  });

  final RangeRepConfirmedTransitionType type;
  final DateTime effectiveAt;
}
