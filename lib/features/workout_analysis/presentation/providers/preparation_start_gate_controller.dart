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

  void arm() {
    if (state.phase != PreparationStartGatePhase.idle) {
      return;
    }

    final now = _clock();
    if (_latestReadiness.isReady) {
      _approve(source: PreparationStartApprovalSource.readiness, now: now);
      return;
    }

    state = PreparationStartGateState(
      phase: PreparationStartGatePhase.monitoring,
      readinessSnapshot: _latestReadiness,
      armedAt: now,
    );
    _scheduleOverrideAvailability();
  }

  void updateReadiness(SetupReadinessSnapshot snapshot) {
    _latestReadiness = snapshot;

    if (state.phase == PreparationStartGatePhase.idle) {
      return;
    }

    if (state.isArmed && snapshot.isReady) {
      _approve(source: PreparationStartApprovalSource.readiness, now: _clock());
      return;
    }

    state = PreparationStartGateState(
      phase: state.phase,
      readinessSnapshot: snapshot,
      armedAt: state.armedAt,
      approvedAt: state.approvedAt,
      approvalSource: state.approvalSource,
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
    _approve(
      source: PreparationStartApprovalSource.manualOverride,
      now: _clock(),
    );
  }

  bool beginLaunch() {
    if (!state.isApproved) {
      return false;
    }
    _overrideTimer?.cancel();
    state = PreparationStartGateState(
      phase: PreparationStartGatePhase.launching,
      readinessSnapshot: _latestReadiness,
      armedAt: state.armedAt,
      approvedAt: state.approvedAt,
      approvalSource: state.approvalSource,
    );
    return true;
  }

  void reset() {
    _overrideTimer?.cancel();
    state = PreparationStartGateState.idle(readinessSnapshot: _latestReadiness);
  }

  void _approve({
    required PreparationStartApprovalSource source,
    required DateTime now,
  }) {
    _overrideTimer?.cancel();
    state = PreparationStartGateState(
      phase: PreparationStartGatePhase.approved,
      readinessSnapshot: _latestReadiness,
      armedAt: state.armedAt,
      approvedAt: now,
      approvalSource: source,
    );
  }

  void _scheduleOverrideAvailability() {
    _overrideTimer?.cancel();
    _overrideTimer = Timer(
      _thresholds.manualOverrideDelay,
      _makeOverrideAvailable,
    );
  }

  @override
  void dispose() {
    _overrideTimer?.cancel();
    super.dispose();
  }
}
