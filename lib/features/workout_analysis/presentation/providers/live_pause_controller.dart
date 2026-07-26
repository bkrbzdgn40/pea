import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/setup_readiness_state.dart';
import '../models/live_pause_state.dart';

final livePauseThresholdsProvider = Provider<LivePauseThresholds>(
  (ref) => LivePauseThresholds.defaults,
);

final livePauseControllerProvider =
    StateNotifierProvider.autoDispose<LivePauseController, LivePauseState>((
      ref,
    ) {
      return LivePauseController(
        thresholds: ref.watch(livePauseThresholdsProvider),
      );
    });

/// Coordinates manual pause, readiness monitoring, and resume countdown.
class LivePauseController extends StateNotifier<LivePauseState> {
  LivePauseController({required LivePauseThresholds thresholds})
    : _thresholds = thresholds,
      super(const LivePauseState.active());

  final LivePauseThresholds _thresholds;
  SetupReadinessSnapshot? _latestReadiness;
  Timer? _countdownTimer;

  void pause({SetupReadinessSnapshot? readinessSnapshot}) {
    if (!state.isActive) {
      return;
    }
    _cancelCountdown();
    _latestReadiness = readinessSnapshot ?? _latestReadiness;
    state = LivePauseState(
      phase: LivePausePhase.paused,
      readinessSnapshot: _latestReadiness,
    );
  }

  void requestResume({required SetupReadinessSnapshot readinessSnapshot}) {
    if (state.phase != LivePausePhase.paused) {
      return;
    }
    _latestReadiness = readinessSnapshot;
    if (readinessSnapshot.isReady) {
      _startCountdown();
      return;
    }
    state = LivePauseState(
      phase: LivePausePhase.resumeMonitoring,
      readinessSnapshot: readinessSnapshot,
    );
  }

  void updateReadiness(SetupReadinessSnapshot readinessSnapshot) {
    _latestReadiness = readinessSnapshot;
    if (state.isActive || state.phase == LivePausePhase.paused) {
      return;
    }

    if (state.isMonitoring && readinessSnapshot.isReady) {
      _startCountdown();
      return;
    }

    if (state.isCountingDown && !readinessSnapshot.isReady) {
      _cancelCountdown();
      state = LivePauseState(
        phase: LivePausePhase.resumeMonitoring,
        readinessSnapshot: readinessSnapshot,
      );
      return;
    }

    state = LivePauseState(
      phase: state.phase,
      readinessSnapshot: readinessSnapshot,
      countdownValue: state.countdownValue,
    );
  }

  void cancelResume() {
    if (state.isActive || state.phase == LivePausePhase.paused) {
      return;
    }
    _cancelCountdown();
    state = LivePauseState(
      phase: LivePausePhase.paused,
      readinessSnapshot: _latestReadiness,
    );
  }

  void handleLifecycleInterruption() {
    if (state.isActive) {
      return;
    }
    _cancelCountdown();
    state = LivePauseState(
      phase: LivePausePhase.paused,
      readinessSnapshot: _latestReadiness,
    );
  }

  void reset() {
    _cancelCountdown();
    state = LivePauseState.active(readinessSnapshot: _latestReadiness);
  }

  void _startCountdown() {
    _cancelCountdown();
    state = LivePauseState(
      phase: LivePausePhase.resumeCountingDown,
      readinessSnapshot: _latestReadiness,
      countdownValue: _thresholds.countdownFrom,
    );
    _scheduleCountdownTick();
  }

  void _advanceCountdown() {
    if (!state.isCountingDown) {
      return;
    }
    if (_latestReadiness?.isReady != true) {
      state = LivePauseState(
        phase: LivePausePhase.resumeMonitoring,
        readinessSnapshot: _latestReadiness,
      );
      return;
    }

    final currentValue = state.countdownValue;
    if (currentValue == null || currentValue <= 1) {
      state = LivePauseState.active(readinessSnapshot: _latestReadiness);
      return;
    }

    state = LivePauseState(
      phase: LivePausePhase.resumeCountingDown,
      readinessSnapshot: _latestReadiness,
      countdownValue: currentValue - 1,
    );
    _scheduleCountdownTick();
  }

  void _scheduleCountdownTick() {
    _countdownTimer = Timer(
      _thresholds.countdownStepDuration,
      _advanceCountdown,
    );
  }

  void _cancelCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
  }

  @override
  void dispose() {
    _cancelCountdown();
    super.dispose();
  }
}
