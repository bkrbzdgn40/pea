import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/pose_acceptance_stabilizer.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_type.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/active_analysis_exercise_provider.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/workout_controller.dart';

void main() {
  test('Jumping Jack live analysis attempts frames at a 50 ms interval', () {
    final container = ProviderContainer(
      overrides: <Override>[
        activeAnalysisExerciseProvider.overrideWithValue(
          ExerciseType.jumpingJack,
        ),
      ],
    );
    addTearDown(container.dispose);

    final factory = container.read(workoutFramePosePipelineFactoryProvider);
    final pipeline = factory(
      poseAcceptanceStabilizer: PoseAcceptanceStabilizer(),
    );

    expect(pipeline.analysisFrameInterval, const Duration(milliseconds: 50));
  });

  test('ordinary exercises keep the shared 100 ms analysis interval', () {
    final container = ProviderContainer(
      overrides: <Override>[
        activeAnalysisExerciseProvider.overrideWithValue(ExerciseType.squat),
      ],
    );
    addTearDown(container.dispose);

    final factory = container.read(workoutFramePosePipelineFactoryProvider);
    final pipeline = factory(
      poseAcceptanceStabilizer: PoseAcceptanceStabilizer(),
    );

    expect(pipeline.analysisFrameInterval, const Duration(milliseconds: 100));
  });
}
