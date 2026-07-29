/// Compile-time gate for workout diagnostics and calibration UI.
///
/// Enable only for explicit engineering builds with:
/// `--dart-define=ENABLE_WORKOUT_DEVELOPER_UI=true`.
const bool workoutDeveloperUiEnabled = bool.fromEnvironment(
  'ENABLE_WORKOUT_DEVELOPER_UI',
  defaultValue: false,
);
