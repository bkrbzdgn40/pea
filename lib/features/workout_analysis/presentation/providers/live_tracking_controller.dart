import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/live_tracking_state.dart';
import 'active_analysis_exercise_provider.dart';

const liveTrackingLossGraceDuration = Duration(milliseconds: 650);

final liveTrackingControllerProvider =
    AutoDisposeNotifierProvider<LiveTrackingController, LiveTrackingState>(
      LiveTrackingController.new,
    );

class LiveTrackingController extends AutoDisposeNotifier<LiveTrackingState> {
  @override
  LiveTrackingState build() {
    ref.keepAlive();
    ref.watch(activeAnalysisExerciseProvider);
    return const LiveTrackingState.tracking();
  }

  void recordInvalidFrame({required DateTime now}) {
    final lossStartedAt = state.lossStartedAt ?? now;
    final elapsed = _nonNegativeDifference(now, lossStartedAt);
    final nextPhase = elapsed >= liveTrackingLossGraceDuration
        ? LiveTrackingPhase.repositionRequired
        : LiveTrackingPhase.temporarilyLost;
    _publish(phase: nextPhase, lossStartedAt: lossStartedAt, now: now);
  }

  void recordPendingAcceptance({required DateTime now}) {
    if (state.phase == LiveTrackingPhase.tracking) {
      return;
    }
    _publish(
      phase: LiveTrackingPhase.reacquiring,
      lossStartedAt: state.lossStartedAt,
      now: now,
    );
  }

  void recordAcceptedFrame({required DateTime now}) {
    if (state.phase == LiveTrackingPhase.tracking) {
      return;
    }
    _publish(phase: LiveTrackingPhase.tracking, lossStartedAt: null, now: now);
  }

  void reset() {
    if (state.phase == LiveTrackingPhase.tracking &&
        state.lossStartedAt == null) {
      return;
    }
    state = const LiveTrackingState.tracking();
  }

  void _publish({
    required LiveTrackingPhase phase,
    required DateTime? lossStartedAt,
    required DateTime now,
  }) {
    if (state.phase == phase && state.lossStartedAt == lossStartedAt) {
      return;
    }
    state = LiveTrackingState(
      phase: phase,
      lossStartedAt: lossStartedAt,
      lastTransitionAt: now,
    );
  }
}

Duration _nonNegativeDifference(DateTime later, DateTime earlier) {
  final difference = later.difference(earlier);
  return difference.isNegative ? Duration.zero : difference;
}
