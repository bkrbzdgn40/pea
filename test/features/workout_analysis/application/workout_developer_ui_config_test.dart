import 'package:flutter_test/flutter_test.dart';
import 'package:pose_estimation_app/features/workout_analysis/application/workout_developer_ui_config.dart';

const bool expectedWorkoutDeveloperUi = bool.fromEnvironment(
  'EXPECT_WORKOUT_DEVELOPER_UI',
  defaultValue: false,
);

void main() {
  test('developer UI follows the explicit compile-time flag', () {
    expect(workoutDeveloperUiEnabled, expectedWorkoutDeveloperUi);
  });
}
