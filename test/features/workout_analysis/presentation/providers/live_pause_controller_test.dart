import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/setup_readiness_state.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/models/live_pause_state.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/live_pause_controller.dart';

void main() {
  test('pauses and waits for readiness before resuming', () {
    final controller = LivePauseController(
      thresholds: LivePauseThresholds(
        countdownFrom: 3,
        countdownStepDuration: const Duration(milliseconds: 10),
      ),
    );
    addTearDown(controller.dispose);

    controller.pause(
      readinessSnapshot: _snapshot(SetupReadinessPhase.noPerson),
    );
    expect(controller.state.phase, LivePausePhase.paused);

    controller.requestResume(
      readinessSnapshot: _snapshot(SetupReadinessPhase.noPerson),
    );
    expect(controller.state.phase, LivePausePhase.resumeMonitoring);
    expect(controller.state.countdownValue, isNull);
  });

  test('runs a 3-2-1 countdown after stable readiness', () async {
    final controller = LivePauseController(
      thresholds: LivePauseThresholds(
        countdownFrom: 3,
        countdownStepDuration: const Duration(milliseconds: 20),
      ),
    );
    addTearDown(controller.dispose);

    controller.pause(
      readinessSnapshot: _snapshot(SetupReadinessPhase.noPerson),
    );
    controller.requestResume(
      readinessSnapshot: _snapshot(SetupReadinessPhase.noPerson),
    );
    controller.updateReadiness(_snapshot(SetupReadinessPhase.ready));

    expect(controller.state.phase, LivePausePhase.resumeCountingDown);
    expect(controller.state.countdownValue, 3);

    await Future<void>.delayed(const Duration(milliseconds: 25));
    expect(controller.state.countdownValue, 2);

    await Future<void>.delayed(const Duration(milliseconds: 25));
    expect(controller.state.countdownValue, 1);

    await Future<void>.delayed(const Duration(milliseconds: 25));
    expect(controller.state.phase, LivePausePhase.active);
  });

  test('cancels countdown when readiness is lost', () {
    final controller = LivePauseController(
      thresholds: LivePauseThresholds(
        countdownFrom: 3,
        countdownStepDuration: const Duration(milliseconds: 10),
      ),
    );
    addTearDown(controller.dispose);

    controller.pause(readinessSnapshot: _snapshot(SetupReadinessPhase.ready));
    controller.requestResume(
      readinessSnapshot: _snapshot(SetupReadinessPhase.ready),
    );
    expect(controller.state.isCountingDown, isTrue);

    controller.updateReadiness(_snapshot(SetupReadinessPhase.offCenter));

    expect(controller.state.phase, LivePausePhase.resumeMonitoring);
    expect(controller.state.countdownValue, isNull);
  });

  test('lifecycle interruption returns an in-progress resume to paused', () {
    final controller = LivePauseController(
      thresholds: LivePauseThresholds(
        countdownFrom: 3,
        countdownStepDuration: const Duration(milliseconds: 10),
      ),
    );
    addTearDown(controller.dispose);

    controller.pause(readinessSnapshot: _snapshot(SetupReadinessPhase.ready));
    controller.requestResume(
      readinessSnapshot: _snapshot(SetupReadinessPhase.ready),
    );
    controller.handleLifecycleInterruption();

    expect(controller.state.phase, LivePausePhase.paused);
    expect(controller.state.countdownValue, isNull);
  });
}

SetupReadinessSnapshot _snapshot(SetupReadinessPhase phase) {
  final now = DateTime.utc(2026, 7, 26, 12);
  return SetupReadinessSnapshot(
    phase: phase,
    evidence: const SetupReadinessEvidence(),
    enteredAt: now,
    updatedAt: now,
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
