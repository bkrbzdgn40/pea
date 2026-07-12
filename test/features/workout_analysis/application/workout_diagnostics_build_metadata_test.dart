import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/workout_diagnostics.dart';

const expectedCommitSha = String.fromEnvironment(
  'PEA_COMMIT_SHA',
  defaultValue: 'unknown',
);

const requireCommitSha = bool.fromEnvironment(
  'REQUIRE_PEA_COMMIT_SHA',
  defaultValue: false,
);

void main() {
  test('snapshot uses compile-time commit SHA metadata', () {
    final startedAt = DateTime.utc(2030, 1, 1, 12);
    final accumulator = WorkoutDiagnosticsAccumulator(
      sessionStartedAt: startedAt,
      analysisKind: 'rangeRep',
    );

    final snapshot = accumulator.snapshot(
      now: startedAt.add(const Duration(seconds: 1)),
    );

    expect(snapshot.appCommitSha, expectedCommitSha);

    if (requireCommitSha) {
      expect(snapshot.appCommitSha, isNot('unknown'));
      expect(RegExp(r'^[0-9a-f]{40}$').hasMatch(snapshot.appCommitSha), isTrue);
    }
  });
}
