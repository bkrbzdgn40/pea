import '../domain/models/range_rep_contract.dart';
import 'biceps_curl_range_rep_analysis_extension.dart';
import 'push_up_range_rep_analysis_extension.dart';
import 'range_rep_exercise_analysis_extension.dart';
import 'range_rep_noop_analysis_extension.dart';
import 'shoulder_press_range_rep_analysis_extension.dart';
import 'squat_range_rep_analysis_extension.dart';

/// Resolves semantic contract metadata to an exercise-specific extension.
///
/// This replaces object-identity checks such as
/// `identical(contract, RangeRepContracts.squat)`.
class RangeRepExerciseAnalysisExtensionFactory {
  const RangeRepExerciseAnalysisExtensionFactory();

  RangeRepExerciseAnalysisExtension create(RangeRepExtensionProfile profile) {
    return switch (profile) {
      RangeRepExtensionProfile.none => NoOpRangeRepExerciseAnalysisExtension(),
      RangeRepExtensionProfile.squat =>
        SquatRangeRepExerciseAnalysisExtension(),
      RangeRepExtensionProfile.pushUp =>
        PushUpRangeRepExerciseAnalysisExtension(),
      RangeRepExtensionProfile.bicepsCurl =>
        BicepsCurlRangeRepExerciseAnalysisExtension(),
      RangeRepExtensionProfile.shoulderPress =>
        ShoulderPressRangeRepExerciseAnalysisExtension(),
    };
  }
}
