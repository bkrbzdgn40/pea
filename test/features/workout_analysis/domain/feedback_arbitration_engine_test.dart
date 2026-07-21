import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/feedback_arbitration_engine.dart';

void main() {
  group('FeedbackArbitrationEngine', () {
    const engine = FeedbackArbitrationEngine();

    test('returns no selection when there are no candidates', () {
      final decision = engine.arbitrate<String>(
        candidates: const <FeedbackCandidate<String>>[],
      );

      expect(decision.hasSelection, isFalse);
      expect(decision.selectedCandidate, isNull);
      expect(decision.selectedValue, isNull);
      expect(decision.consideredCandidates, isEmpty);
    });

    test('selects the highest-priority candidate', () {
      final decision = engine.arbitrate<String>(
        candidates: const <FeedbackCandidate<String>>[
          FeedbackCandidate<String>(
            id: 'movement',
            value: 'descend',
            priority: FeedbackPriority.movement,
          ),
          FeedbackCandidate<String>(
            id: 'corrective',
            value: 'maintain_form',
            priority: FeedbackPriority.corrective,
          ),
          FeedbackCandidate<String>(
            id: 'system',
            value: 'body_not_visible',
            priority: FeedbackPriority.systemState,
          ),
        ],
      );

      expect(decision.selectedValue, 'body_not_visible');
    });

    test('corrective feedback outranks non-blocking status', () {
      final decision = engine.arbitrate<String>(
        candidates: const <FeedbackCandidate<String>>[
          FeedbackCandidate<String>(
            id: 'status',
            value: 'ready',
            priority: FeedbackPriority.status,
          ),
          FeedbackCandidate<String>(
            id: 'corrective',
            value: 'maintain_form',
            priority: FeedbackPriority.corrective,
          ),
        ],
      );

      expect(decision.selectedValue, 'maintain_form');
    });

    test('preserves declaration order when priorities tie', () {
      final decision = engine.arbitrate<String>(
        candidates: const <FeedbackCandidate<String>>[
          FeedbackCandidate<String>(
            id: 'first',
            value: 'control_descent',
            priority: FeedbackPriority.corrective,
          ),
          FeedbackCandidate<String>(
            id: 'second',
            value: 'control_ascent',
            priority: FeedbackPriority.corrective,
          ),
        ],
      );

      expect(decision.selectedValue, 'control_descent');
    });

    test('retains all considered candidates for diagnostics', () {
      final decision = engine.arbitrate<int>(
        candidates: const <FeedbackCandidate<int>>[
          FeedbackCandidate<int>(
            id: 'one',
            value: 1,
            priority: FeedbackPriority.movement,
          ),
          FeedbackCandidate<int>(
            id: 'two',
            value: 2,
            priority: FeedbackPriority.corrective,
          ),
        ],
      );

      expect(
        decision.consideredCandidates.map((candidate) => candidate.id),
        <String>['one', 'two'],
      );
      expect(
        () => decision.consideredCandidates.add(
          const FeedbackCandidate<int>(
            id: 'three',
            value: 3,
            priority: FeedbackPriority.systemState,
          ),
        ),
        throwsUnsupportedError,
      );
    });

    test('rejects duplicate candidate ids in one decision', () {
      expect(
        () => engine.arbitrate<String>(
          candidates: const <FeedbackCandidate<String>>[
            FeedbackCandidate<String>(
              id: 'duplicate',
              value: 'first',
              priority: FeedbackPriority.movement,
            ),
            FeedbackCandidate<String>(
              id: 'duplicate',
              value: 'second',
              priority: FeedbackPriority.corrective,
            ),
          ],
        ),
        throwsStateError,
      );
    });
  });
}
