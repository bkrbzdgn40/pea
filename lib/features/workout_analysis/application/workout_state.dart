import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class WorkoutState {
  final List<PoseLandmark>? landmarks;
  final int repCount;
  final bool isFormBad;
  final double currentAngle;
  final double lastRepScore;
  final double lastRepROM;
  final String feedbackMessage;
  final String currentPhase;
  final double cameraFps;
  final double analysisFps;

  WorkoutState({
    this.landmarks,
    this.repCount = 0,
    this.isFormBad = false,
    this.currentAngle = 0.0,
    this.lastRepScore = 0.0,
    this.lastRepROM = 0.0,
    this.feedbackMessage = "Hazır mısın?",
    this.currentPhase = "NEUTRAL",
    this.cameraFps = 0.0,
    this.analysisFps = 0.0,
  });

  // Mevcut durumu seçili alanlarla kopyalar.
  WorkoutState copyWith({
    List<PoseLandmark>? landmarks,
    int? repCount,
    bool? isFormBad,
    double? currentAngle,
    double? lastRepScore,
    double? lastRepROM,
    String? feedbackMessage,
    String? currentPhase,
    double? cameraFps,
    double? analysisFps,
  }) {
    return WorkoutState(
      landmarks: landmarks ?? this.landmarks,
      repCount: repCount ?? this.repCount,
      isFormBad: isFormBad ?? this.isFormBad,
      currentAngle: currentAngle ?? this.currentAngle,
      lastRepScore: lastRepScore ?? this.lastRepScore,
      lastRepROM: lastRepROM ?? this.lastRepROM,
      feedbackMessage: feedbackMessage ?? this.feedbackMessage,
      currentPhase: currentPhase ?? this.currentPhase,
      cameraFps: cameraFps ?? this.cameraFps,
      analysisFps: analysisFps ?? this.analysisFps,
    );
  }
}
