import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/domain/models/exercise_type.dart';
import 'package:pose_estimation_app/features/workout_analysis/presentation/providers/recent_exercises_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('loads known ids, removes duplicates, and ignores stale ids', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      RecentExercisesController.preferenceKey: <String>[
        'shoulder_press',
        'unknown_exercise',
        'biceps_curl',
        'shoulder_press',
      ],
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final recent = await container.read(recentExercisesProvider.future);

    expect(recent, const <ExerciseType>[
      ExerciseType.shoulderPress,
      ExerciseType.bicepsCurl,
    ]);
  });

  test('moves the latest exercise to the front and caps the list', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      RecentExercisesController.preferenceKey: <String>[
        'squat',
        'plank',
        'lunge',
        'push_up',
      ],
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(recentExercisesProvider.future);

    await container
        .read(recentExercisesProvider.notifier)
        .record(ExerciseType.plank);
    await container
        .read(recentExercisesProvider.notifier)
        .record(ExerciseType.bicepsCurl);

    expect(
      container.read(recentExercisesProvider).valueOrNull,
      const <ExerciseType>[
        ExerciseType.bicepsCurl,
        ExerciseType.plank,
        ExerciseType.squat,
        ExerciseType.lunge,
      ],
    );

    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getStringList(RecentExercisesController.preferenceKey),
      const <String>['biceps_curl', 'plank', 'squat', 'lunge'],
    );
  });
}
