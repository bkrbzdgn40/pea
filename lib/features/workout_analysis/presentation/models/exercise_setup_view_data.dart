/// Localized, presentation-ready preparation copy for one exercise.
///
/// The model intentionally contains no domain enums. Screens can render this
/// data without exposing internal setup identifiers to the user.
class ExerciseSetupViewData {
  ExerciseSetupViewData({
    required this.exerciseId,
    required this.exerciseName,
    required this.cameraViewLabel,
    required this.cameraViewInstruction,
    required this.bodyCoverageInstruction,
    required this.startPoseInstruction,
    required this.setupPositionLabel,
    required this.cameraPlacementInstruction,
    required List<String> environmentInstructions,
  }) : environmentInstructions = List<String>.unmodifiable(
         environmentInstructions,
       );

  final String exerciseId;
  final String exerciseName;
  final String cameraViewLabel;
  final String cameraViewInstruction;
  final String bodyCoverageInstruction;
  final String startPoseInstruction;
  final String setupPositionLabel;
  final String cameraPlacementInstruction;
  final List<String> environmentInstructions;

  /// Stable order for later preparation surfaces.
  List<String> get orderedInstructions => List<String>.unmodifiable(<String>[
    cameraViewInstruction,
    bodyCoverageInstruction,
    startPoseInstruction,
    cameraPlacementInstruction,
    ...environmentInstructions,
  ]);
}
