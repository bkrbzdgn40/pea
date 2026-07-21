import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/engine_kind.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/feedback_delivery_controller.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/workout_state.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_type.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/active_analysis_exercise_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/exercise_config_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/feedback_delivery_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/pose_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/selected_exercise_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/settings_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/workout_controller.dart';

import '../../../../support/workout_analysis_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'rebuilds the same controller when a planned workout changes exercise',
    () {
      final detector = TestQueuedPoseDetector();
      final clock = TestFakeClock();
      final container = ProviderContainer(
        overrides: <Override>[
          exerciseConfigProvider.overrideWith((ref) {
            final exercise = ref.watch(activeAnalysisExerciseProvider);
            return exercise == ExerciseType.plank
                ? buildPlankConfig()
                : buildSquatConfig();
          }),
          poseDetectorProvider.overrideWith((ref) => detector),
          workoutClockProvider.overrideWithValue(clock.now),
          feedbackDeliveryProvider.overrideWithValue(
            const _NoopFeedbackDelivery(),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.read(selectedExerciseProvider.notifier).state =
          ExerciseType.squat;
      final subscription = container.listen<WorkoutState>(
        workoutControllerProvider,
        (previous, next) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      final controller = container.read(workoutControllerProvider.notifier);
      expect(
        container.read(workoutControllerProvider).analysisKind,
        EngineKind.rangeRep,
      );

      container.read(selectedExerciseProvider.notifier).state =
          ExerciseType.plank;

      final nextState = container.read(workoutControllerProvider);
      expect(
        container.read(workoutControllerProvider.notifier),
        same(controller),
      );
      expect(nextState.analysisKind, EngineKind.hold);
    },
  );

  test('uses the active language for live workout feedback', () {
    final detector = TestQueuedPoseDetector();
    final clock = TestFakeClock();
    final container = ProviderContainer(
      overrides: <Override>[
        runtimeAppLanguageProvider.overrideWith((ref) => AppLanguage.english),
        exerciseConfigProvider.overrideWith((ref) => buildSquatConfig()),
        poseDetectorProvider.overrideWith((ref) => detector),
        workoutClockProvider.overrideWithValue(clock.now),
        feedbackDeliveryProvider.overrideWithValue(
          const _NoopFeedbackDelivery(),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.read(selectedExerciseProvider.notifier).state =
        ExerciseType.squat;
    final subscription = container.listen<WorkoutState>(
      workoutControllerProvider,
      (previous, next) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    expect(
      container.read(workoutControllerProvider).feedbackMessage,
      'Move to the starting position.',
    );
  });
}

class _NoopFeedbackDelivery implements FeedbackDeliveryPort {
  const _NoopFeedbackDelivery();

  @override
  Future<FeedbackDeliveryResult> deliver(FeedbackDeliveryCue cue) async {
    return FeedbackDeliveryResult(
      disposition: FeedbackDeliveryDisposition.delivered,
      cue: cue,
      hapticPattern: FeedbackHapticPattern.none,
    );
  }

  @override
  void reset() {}

  @override
  Future<void> stop() async {}
}
