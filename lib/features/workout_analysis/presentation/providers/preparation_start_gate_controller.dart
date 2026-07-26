import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/setup_readiness_state.dart';
import '../models/preparation_start_gate_state.dart';
import '../models/setup_readiness_view_data.dart';
import 'preparation_readiness_controller.dart';

final preparationStartGateClockProvider = Provider<DateTime Function()>((ref) {
  return DateTime.now;
});

final preparationStartGateThresholdsProvider =
    Provider<PreparationStartGateThresholds>(
      (ref) => PreparationStartGateThresholds.defaults,
    );

/// One-tap preparation gate bound to the stable readiness request on screen.
final preparationStartGateProvider = StateNotifierProvider.autoDispose
    .family<
      PreparationStartGateController,
      PreparationStartGateState,
      SetupReadinessRequest
    >((ref, request) {
      final readinessProvider = preparationReadinessStateProvider(request);
      final controller = PreparationStartGateController(
        thresholds: ref.watch(preparationStartGateThresholdsProvider),
        clock: ref.watch(preparationStartGateClockProvider),
        initialReadiness: ref.read(readinessProvider),
      );
      ref.listen<SetupReadinessSnapshot>(readinessProvider, (_, next) {
        controller.updateReadiness(next);
      });
      return controller;
    });

class PreparationStartGateController
    extends StateNotifier<PreparationStartGateState> {
  PreparationStartGateController({
    required PreparationStartGateThresholds thresholds,
    required DateTime Function() clock,
    required SetupReadinessSnapshot initialReadiness,
  }) : _thresholds = thresholds,
       _clock = clock,
       _latestReadiness = initialReadiness,
       super(
         PreparationStartGateState.idle(readinessSnapshot: initialReadiness),
       );

  final PreparationStartGateThresholds _thresholds;
  final DateTime Function() _clock;
  SetupReadinessSnapshot _latestReadiness;
  Timer? _overrideTimer;
  Timer? _countdownTimer;

  void arm() {
    if (state.phase != PreparationStartGatePhase.idle) {
      return;
    }

    final now = _clock();
    if (_latestReadiness.isReady) {
      _startCountdown(
        source: PreparationStartApprovalSource.readiness,
        now: now,
        armedAt: now,
      );
      return;
    }

    state = PreparationStartGateState(
      phase: PreparationStartGatePhase.monitoring,
      readinessSnapshot: _latestReadiness,
      armedAt: now,
    );
    _scheduleOverrideAvailability(_thresholds.manualOverrideDelay);
  }

  void updateReadiness(SetupReadinessSnapshot snapshot) {
    _latestReadiness = snapshot;

    if (state.phase == PreparationStartGatePhase.idle) {
      return;
    }

    if ((state.phase == PreparationStartGatePhase.monitoring ||
            state.phase == PreparationStartGatePhase.overrideAvailable) &&
        snapshot.isReady) {
      _startCountdown(
        source: PreparationStartApprovalSource.readiness,
        now: _clock(),
        armedAt: state.armedAt,
      );
      return;
    }

    if (state.isCountingDown &&
        state.approvalSource == PreparationStartApprovalSource.readiness &&
        !snapshot.isReady) {
      _resumeMonitoringAfterCountdownCancellation(now: _clock());
      return;
    }

    state = PreparationStartGateState(
      phase: state.phase,
      readinessSnapshot: snapshot,
      armedAt: state.armedAt,
      countdownStartedAt: state.countdownStartedAt,
      approvedAt: state.approvedAt,
      approvalSource: state.approvalSource,
      countdownValue: state.countdownValue,
    );
  }

  void _makeOverrideAvailable() {
    if (state.phase != PreparationStartGatePhase.monitoring) {
      return;
    }

    state = PreparationStartGateState(
      phase: PreparationStartGatePhase.overrideAvailable,
      readinessSnapshot: _latestReadiness,
      armedAt: state.armedAt,
    );
  }

  void approveOverride() {
    if (!state.canOverride) {
      return;
    }
    _startCountdown(
      source: PreparationStartApprovalSource.manualOverride,
      now: _clock(),
      armedAt: state.armedAt,
    );
  }

  bool beginLaunch() {
    if (!state.isApproved) {
      return false;
    }
    _cancelTimers();
    state = PreparationStartGateState(
      phase: PreparationStartGatePhase.launching,
      readinessSnapshot: _latestReadiness,
      armedAt: state.armedAt,
      countdownStartedAt: state.countdownStartedAt,
      approvedAt: state.approvedAt,
      approvalSource: state.approvalSource,
    );
    return true;
  }

  void reset() {
    _cancelTimers();
    state = PreparationStartGateState.idle(readinessSnapshot: _latestReadiness);
  }

  void _startCountdown({
    required PreparationStartApprovalSource source,
    required DateTime now,
    required DateTime? armedAt,
  }) {
    _cancelTimers();
    state = PreparationStartGateState(
      phase: PreparationStartGatePhase.countingDown,
      readinessSnapshot: _latestReadiness,
      armedAt: armedAt ?? now,
      countdownStartedAt: now,
      approvalSource: source,
      countdownValue: _thresholds.countdownFrom,
    );
    _scheduleCountdownTick();
  }

  void _advanceCountdown() {
    if (!state.isCountingDown) {
      return;
    }

    if (state.approvalSource == PreparationStartApprovalSource.readiness &&
        !_latestReadiness.isReady) {
      _resumeMonitoringAfterCountdownCancellation(now: _clock());
      return;
    }

    final currentValue = state.countdownValue;
    if (currentValue == null) {
      reset();
      return;
    }

    if (currentValue <= 1) {
      _approve(source: state.approvalSource!, now: _clock());
      return;
    }

    state = PreparationStartGateState(
      phase: PreparationStartGatePhase.countingDown,
      readinessSnapshot: _latestReadiness,
      armedAt: state.armedAt,
      countdownStartedAt: state.countdownStartedAt,
      approvalSource: state.approvalSource,
      countdownValue: currentValue - 1,
    );
    _scheduleCountdownTick();
  }

  void _resumeMonitoringAfterCountdownCancellation({required DateTime now}) {
    _countdownTimer?.cancel();
    final armedAt = state.armedAt ?? now;
    final elapsed = now.difference(armedAt);
    final normalizedElapsed = elapsed.isNegative ? Duration.zero : elapsed;
    final remaining = _thresholds.manualOverrideDelay - normalizedElapsed;
    final overrideAvailable = remaining <= Duration.zero;

    state = PreparationStartGateState(
      phase: overrideAvailable
          ? PreparationStartGatePhase.overrideAvailable
          : PreparationStartGatePhase.monitoring,
      readinessSnapshot: _latestReadiness,
      armedAt: armedAt,
    );

    if (!overrideAvailable) {
      _scheduleOverrideAvailability(remaining);
    }
  }

  void _approve({
    required PreparationStartApprovalSource source,
    required DateTime now,
  }) {
    _cancelTimers();
    state = PreparationStartGateState(
      phase: PreparationStartGatePhase.approved,
      readinessSnapshot: _latestReadiness,
      armedAt: state.armedAt,
      countdownStartedAt: state.countdownStartedAt,
      approvedAt: now,
      approvalSource: source,
    );
  }

  void _scheduleOverrideAvailability(Duration delay) {
    _overrideTimer?.cancel();
    _overrideTimer = Timer(delay, _makeOverrideAvailable);
  }

  void _scheduleCountdownTick() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer(
      _thresholds.countdownStepDuration,
      _advanceCountdown,
    );
  }

  void _cancelTimers() {
    _overrideTimer?.cancel();
    _countdownTimer?.cancel();
  }

  @override
  void dispose() {
    _cancelTimers();
    super.dispose();
  }
}
