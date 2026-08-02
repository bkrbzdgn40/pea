import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/setup_readiness_state.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/models/preparation_start_gate_state.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/preparation_start_gate_controller.dart';

void main() {
  final startedAt = DateTime.utc(2026, 7, 26, 12);

  test('counts down before approving stable readiness', () async {
    var now = startedAt;
    final controller = PreparationStartGateController(
      thresholds: PreparationStartGateThresholds(
        manualOverrideDelay: const Duration(seconds: 10),
        countdownStepDuration: const Duration(milliseconds: 20),
      ),
      clock: () => now,
      initialReadiness: _snapshot(SetupReadinessPhase.noPerson, now),
    );
    addTearDown(controller.dispose);

    controller.arm();
    expect(controller.state.phase, PreparationStartGatePhase.monitoring);

    now = now.add(const Duration(seconds: 2));
    controller.updateReadiness(_snapshot(SetupReadinessPhase.ready, now));

    expect(controller.state.phase, PreparationStartGatePhase.countingDown);
    expect(controller.state.countdownValue, 3);
    expect(
      controller.state.approvalSource,
      PreparationStartApprovalSource.readiness,
    );

    await Future<void>.delayed(const Duration(milliseconds: 25));
    expect(controller.state.countdownValue, 2);

    await Future<void>.delayed(const Duration(milliseconds: 25));
    expect(controller.state.countdownValue, 1);

    now = now.add(const Duration(seconds: 3));
    await Future<void>.delayed(const Duration(milliseconds: 25));

    expect(controller.state.phase, PreparationStartGatePhase.approved);
    expect(
      controller.state.approvalSource,
      PreparationStartApprovalSource.readiness,
    );
    expect(controller.state.approvedAt, now);
  });

  test('cancels readiness countdown when readiness is lost', () async {
    var now = startedAt;
    final controller = PreparationStartGateController(
      thresholds: PreparationStartGateThresholds(
        manualOverrideDelay: const Duration(seconds: 10),
        countdownStepDuration: const Duration(milliseconds: 20),
      ),
      clock: () => now,
      initialReadiness: _snapshot(SetupReadinessPhase.ready, now),
    );
    addTearDown(controller.dispose);

    controller.arm();
    expect(controller.state.phase, PreparationStartGatePhase.countingDown);

    now = now.add(const Duration(seconds: 1));
    controller.updateReadiness(_snapshot(SetupReadinessPhase.offCenter, now));

    expect(controller.state.phase, PreparationStartGatePhase.monitoring);
    expect(controller.state.countdownValue, isNull);
    expect(controller.state.approvalSource, isNull);

    await Future<void>.delayed(const Duration(milliseconds: 70));
    expect(controller.state.phase, PreparationStartGatePhase.monitoring);
  });

  test('pauses a readiness countdown during brief evidence loss', () async {
    var now = startedAt;
    final controller = PreparationStartGateController(
      thresholds: PreparationStartGateThresholds(
        manualOverrideDelay: const Duration(seconds: 10),
        countdownStepDuration: const Duration(milliseconds: 250),
      ),
      clock: () => now,
      initialReadiness: _snapshot(SetupReadinessPhase.ready, now),
    );
    addTearDown(controller.dispose);

    controller.arm();
    expect(controller.state.countdownValue, 3);

    now = now.add(const Duration(milliseconds: 70));
    controller.updateReadiness(
      _snapshot(SetupReadinessPhase.temporarilyLost, now),
    );

    expect(controller.state.phase, PreparationStartGatePhase.countingDown);
    expect(controller.state.countdownValue, 3);

    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(controller.state.countdownValue, 3);

    now = now.add(const Duration(milliseconds: 430));
    controller.updateReadiness(_snapshot(SetupReadinessPhase.ready, now));

    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(controller.state.countdownValue, 3);

    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(controller.state.countdownValue, 2);
  });

  test('pauses countdown for a transient start-pose mismatch', () async {
    var now = startedAt;
    final controller = PreparationStartGateController(
      thresholds: PreparationStartGateThresholds(
        manualOverrideDelay: const Duration(seconds: 10),
        countdownStepDuration: const Duration(milliseconds: 250),
      ),
      clock: () => now,
      initialReadiness: _snapshot(SetupReadinessPhase.ready, now),
    );
    addTearDown(controller.dispose);

    controller.arm();
    now = now.add(const Duration(milliseconds: 70));
    controller.updateReadiness(
      _snapshot(
        SetupReadinessPhase.temporarilyLost,
        now,
        rawPhase: SetupReadinessPhase.startPoseMissing,
      ),
    );

    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(controller.state.countdownValue, 3);

    now = now.add(const Duration(milliseconds: 250));
    controller.updateReadiness(_snapshot(SetupReadinessPhase.ready, now));

    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(controller.state.countdownValue, 3);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(controller.state.countdownValue, 2);
  });

  test(
    'cancels a paused countdown after readiness loss becomes conclusive',
    () async {
      final controller = PreparationStartGateController(
        thresholds: PreparationStartGateThresholds(
          manualOverrideDelay: const Duration(seconds: 10),
          countdownStepDuration: const Duration(milliseconds: 20),
        ),
        clock: () => startedAt,
        initialReadiness: _snapshot(SetupReadinessPhase.ready, startedAt),
      );
      addTearDown(controller.dispose);

      controller.arm();
      controller.updateReadiness(
        _snapshot(SetupReadinessPhase.temporarilyLost, startedAt),
      );
      controller.updateReadiness(
        _snapshot(SetupReadinessPhase.noPerson, startedAt),
      );

      expect(controller.state.phase, PreparationStartGatePhase.monitoring);
      expect(controller.state.countdownValue, isNull);

      await Future<void>.delayed(const Duration(milliseconds: 70));
      expect(controller.state.phase, PreparationStartGatePhase.monitoring);
    },
  );

  test(
    'offers a controlled override and counts down before approval',
    () async {
      final controller = PreparationStartGateController(
        thresholds: PreparationStartGateThresholds(
          manualOverrideDelay: const Duration(milliseconds: 5),
          countdownStepDuration: const Duration(milliseconds: 5),
        ),
        clock: () => startedAt,
        initialReadiness: _snapshot(
          SetupReadinessPhase.startPoseMissing,
          startedAt,
        ),
      );
      addTearDown(controller.dispose);

      controller.arm();
      await Future<void>.delayed(const Duration(milliseconds: 12));

      expect(
        controller.state.phase,
        PreparationStartGatePhase.overrideAvailable,
      );
      expect(controller.state.canOverride, isTrue);

      controller.approveOverride();

      expect(controller.state.phase, PreparationStartGatePhase.countingDown);
      expect(controller.state.countdownValue, 3);
      expect(
        controller.state.approvalSource,
        PreparationStartApprovalSource.manualOverride,
      );

      controller.updateReadiness(
        _snapshot(SetupReadinessPhase.noPerson, startedAt),
      );
      expect(controller.state.phase, PreparationStartGatePhase.countingDown);

      await Future<void>.delayed(const Duration(milliseconds: 25));

      expect(controller.state.phase, PreparationStartGatePhase.approved);
      expect(
        controller.state.approvalSource,
        PreparationStartApprovalSource.manualOverride,
      );
    },
  );

  test('cancel resets monitoring and countdown phases', () {
    final controller = PreparationStartGateController(
      thresholds: PreparationStartGateThresholds(
        manualOverrideDelay: const Duration(seconds: 10),
      ),
      clock: () => startedAt,
      initialReadiness: _snapshot(SetupReadinessPhase.offCenter, startedAt),
    );
    addTearDown(controller.dispose);

    controller.arm();
    controller.reset();

    expect(controller.state.phase, PreparationStartGatePhase.idle);
    expect(controller.state.armedAt, isNull);

    controller.updateReadiness(_snapshot(SetupReadinessPhase.ready, startedAt));
    controller.arm();
    expect(controller.state.phase, PreparationStartGatePhase.countingDown);

    controller.reset();
    expect(controller.state.phase, PreparationStartGatePhase.idle);
    expect(controller.state.countdownValue, isNull);
  });

  test('launch can begin only after countdown approval', () async {
    final controller = PreparationStartGateController(
      thresholds: PreparationStartGateThresholds(
        manualOverrideDelay: Duration.zero,
        countdownStepDuration: const Duration(milliseconds: 5),
      ),
      clock: () => startedAt,
      initialReadiness: _snapshot(SetupReadinessPhase.ready, startedAt),
    );
    addTearDown(controller.dispose);

    expect(controller.beginLaunch(), isFalse);

    controller.arm();
    expect(controller.state.phase, PreparationStartGatePhase.countingDown);
    expect(controller.beginLaunch(), isFalse);

    await Future<void>.delayed(const Duration(milliseconds: 25));

    expect(controller.state.phase, PreparationStartGatePhase.approved);
    expect(controller.beginLaunch(), isTrue);
    expect(controller.state.phase, PreparationStartGatePhase.launching);
    expect(controller.beginLaunch(), isFalse);
  });
}

SetupReadinessSnapshot _snapshot(
  SetupReadinessPhase phase,
  DateTime timestamp, {
  SetupReadinessPhase? rawPhase,
}) {
  return SetupReadinessSnapshot(
    phase: phase,
    evidence: const SetupReadinessEvidence(),
    enteredAt: timestamp,
    updatedAt: timestamp,
    diagnostics: SetupReadinessDiagnosticsSnapshot(
      rawPhase: rawPhase ?? phase,
      framingStatus: null,
      cameraViewStatus: null,
      startPoseStatus: null,
      stableEvidenceDuration: Duration.zero,
      temporaryLossDuration: Duration.zero,
      stabilityProgress: phase == SetupReadinessPhase.ready ? 1 : 0,
      confidence: phase == SetupReadinessPhase.ready ? 1 : 0,
    ),
  );
}
