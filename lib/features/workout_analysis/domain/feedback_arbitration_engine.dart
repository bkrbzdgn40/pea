/// Relative importance used when multiple feedback candidates are valid at the
/// same decision point.
///
/// The enum intentionally models arbitration only. Repeat suppression,
/// cooldown, voice, haptics, and presentation copy belong to delivery layers.
enum FeedbackPriority {
  status(50),
  movement(100),
  corrective(200),
  systemState(300);

  const FeedbackPriority(this.weight);

  final int weight;
}

/// One domain feedback option considered by [FeedbackArbitrationEngine].
class FeedbackCandidate<T> {
  const FeedbackCandidate({
    required this.id,
    required this.value,
    required this.priority,
  });

  final String id;
  final T value;
  final FeedbackPriority priority;
}

/// Immutable result of one arbitration decision.
class FeedbackArbitrationDecision<T> {
  FeedbackArbitrationDecision({
    required List<FeedbackCandidate<T>> consideredCandidates,
    required this.selectedCandidate,
  }) : consideredCandidates = List<FeedbackCandidate<T>>.unmodifiable(
         consideredCandidates,
       );

  final List<FeedbackCandidate<T>> consideredCandidates;
  final FeedbackCandidate<T>? selectedCandidate;

  bool get hasSelection => selectedCandidate != null;

  T? get selectedValue => selectedCandidate?.value;
}

/// Selects one feedback candidate without owning user-facing delivery.
///
/// Higher [FeedbackPriority] wins. Candidates with the same priority preserve
/// declaration order, making exercise/family-specific tie-breaking explicit at
/// the call site instead of hiding it in this generic engine.
class FeedbackArbitrationEngine {
  const FeedbackArbitrationEngine();

  FeedbackArbitrationDecision<T> arbitrate<T>({
    required Iterable<FeedbackCandidate<T>> candidates,
  }) {
    final consideredCandidates = candidates.toList(growable: false);
    final seenIds = <String>{};
    FeedbackCandidate<T>? selectedCandidate;

    for (final candidate in consideredCandidates) {
      if (!seenIds.add(candidate.id)) {
        throw StateError('Duplicate feedback candidate id: ${candidate.id}.');
      }

      final selected = selectedCandidate;
      if (selected == null ||
          candidate.priority.weight > selected.priority.weight) {
        selectedCandidate = candidate;
      }
    }

    return FeedbackArbitrationDecision<T>(
      consideredCandidates: consideredCandidates,
      selectedCandidate: selectedCandidate,
    );
  }
}
