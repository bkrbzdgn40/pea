import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_type.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/models/live_tracking_state.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/active_analysis_exercise_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/live_tracking_controller.dart';

void main() {
  late ProviderContainer container;
  late LiveTrackingController controller;
  final start = DateTime(2026, 7, 26, 12);

  setUp(() {
    container = ProviderContainer(
      overrides: <Override>[
        activeAnalysisExerciseProvider.overrideWithValue(ExerciseType.squat),
      ],
    );
    controller = container.read(liveTrackingControllerProvider.notifier);
  });

  tearDown(() => container.dispose());

  test('starts in tracking state', () {
    expect(
      container.read(liveTrackingControllerProvider).phase,
      LiveTrackingPhase.tracking,
    );
  });

  test('uses a brief-loss grace before requiring repositioning', () {
    controller.recordInvalidFrame(now: start);
    expect(
      container.read(liveTrackingControllerProvider).phase,
      LiveTrackingPhase.temporarilyLost,
    );

    controller.recordInvalidFrame(
      now: start.add(liveTrackingLossGraceDuration),
    );
    expect(
      container.read(liveTrackingControllerProvider).phase,
      LiveTrackingPhase.repositionRequired,
    );
  });

  test('marks pending accepted poses as reacquiring after a loss', () {
    controller.recordInvalidFrame(now: start);
    controller.recordPendingAcceptance(
      now: start.add(const Duration(milliseconds: 100)),
    );

    expect(
      container.read(liveTrackingControllerProvider).phase,
      LiveTrackingPhase.reacquiring,
    );
  });

  test('returns to tracking only after an accepted frame', () {
    controller.recordInvalidFrame(now: start);
    controller.recordPendingAcceptance(
      now: start.add(const Duration(milliseconds: 100)),
    );
    controller.recordAcceptedFrame(
      now: start.add(const Duration(milliseconds: 200)),
    );

    final state = container.read(liveTrackingControllerProvider);
    expect(state.phase, LiveTrackingPhase.tracking);
    expect(state.lossStartedAt, isNull);
  });

  test('keeps the original loss window when reacquisition fails', () {
    controller.recordInvalidFrame(now: start);
    controller.recordPendingAcceptance(
      now: start.add(const Duration(milliseconds: 100)),
    );
    controller.recordInvalidFrame(
      now: start.add(liveTrackingLossGraceDuration),
    );

    expect(
      container.read(liveTrackingControllerProvider).phase,
      LiveTrackingPhase.repositionRequired,
    );
  });
}
