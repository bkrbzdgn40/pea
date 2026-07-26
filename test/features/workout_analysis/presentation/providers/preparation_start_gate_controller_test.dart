import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/setup_readiness_state.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/models/preparation_start_gate_state.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/preparation_start_gate_controller.dart';

void main() {
  final startedAt = DateTime.utc(2026, 7, 26, 12);

  test('approves automatically after stable readiness arrives', () {
    var now = startedAt;
    final controller = PreparationStartGateController(
      thresholds: PreparationStartGateThresholds(
        manualOverrideDelay: const Duration(seconds: 10),
      ),
      clock: () => now,
      initialReadiness: _snapshot(SetupReadinessPhase.noPerson, now),
    );
    addTearDown(controller.dispose);

    controller.arm();
    expect(controller.state.phase, PreparationStartGatePhase.monitoring);

    now = now.add(const Duration(seconds: 2));
    controller.updateReadiness(_snapshot(SetupReadinessPhase.ready, now));

    expect(controller.state.phase, PreparationStartGatePhase.approved);
    expect(
      controller.state.approvalSource,
      PreparationStartApprovalSource.readiness,
    );
    expect(controller.state.approvedAt, now);
  });

  test('offers a controlled override after the delay', () async {
    final controller = PreparationStartGateController(
      thresholds: PreparationStartGateThresholds(
        manualOverrideDelay: const Duration(milliseconds: 5),
      ),
      clock: () => startedAt,
      initialReadiness: _snapshot(
        SetupReadinessPhase.startPoseMissing,
        startedAt,
      ),
    );
    addTearDown(controller.dispose);

    controller.arm();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(controller.state.phase, PreparationStartGatePhase.overrideAvailable);
    expect(controller.state.canOverride, isTrue);

    controller.approveOverride();

    expect(controller.state.phase, PreparationStartGatePhase.approved);
    expect(
      controller.state.approvalSource,
      PreparationStartApprovalSource.manualOverride,
    );
  });

  test('cancel resets the armed gate', () {
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
  });

  test('launch can begin only after approval', () {
    final controller = PreparationStartGateController(
      thresholds: PreparationStartGateThresholds(
        manualOverrideDelay: Duration.zero,
      ),
      clock: () => startedAt,
      initialReadiness: _snapshot(SetupReadinessPhase.ready, startedAt),
    );
    addTearDown(controller.dispose);

    expect(controller.beginLaunch(), isFalse);

    controller.arm();
    expect(controller.state.phase, PreparationStartGatePhase.approved);
    expect(controller.beginLaunch(), isTrue);
    expect(controller.state.phase, PreparationStartGatePhase.launching);
    expect(controller.beginLaunch(), isFalse);
  });
}

SetupReadinessSnapshot _snapshot(
  SetupReadinessPhase phase,
  DateTime timestamp,
) {
  return SetupReadinessSnapshot(
    phase: phase,
    evidence: const SetupReadinessEvidence(),
    enteredAt: timestamp,
    updatedAt: timestamp,
    diagnostics: SetupReadinessDiagnosticsSnapshot(
      rawPhase: phase,
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
