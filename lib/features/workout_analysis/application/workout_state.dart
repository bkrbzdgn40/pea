import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class WorkoutCalibrationMetrics {
  const WorkoutCalibrationMetrics({
    this.currentBackAngle = 0.0,
    this.formThreshold = 0.0,
    this.currentRepWorstBackAngle = 0.0,
    this.currentRepHadFormViolation = false,
    this.hasLastRepBreakdown = false,
    this.lastRepRomScore = 0.0,
    this.lastRepDescentScore = 0.0,
    this.lastRepAscentScoreCandidate = 0.0,
    this.lastRepWorstBackAngle = 0.0,
    this.lastRepHadFormViolation = false,
  });

  final double currentBackAngle;
  final double formThreshold;
  final double currentRepWorstBackAngle;
  final bool currentRepHadFormViolation;
  final bool hasLastRepBreakdown;
  final double lastRepRomScore;
  final double lastRepDescentScore;
  final double lastRepAscentScoreCandidate;
  final double lastRepWorstBackAngle;
  final bool lastRepHadFormViolation;
}

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
  final WorkoutCalibrationMetrics calibrationMetrics;

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
    this.calibrationMetrics = const WorkoutCalibrationMetrics(),
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
    WorkoutCalibrationMetrics? calibrationMetrics,
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
      calibrationMetrics: calibrationMetrics ?? this.calibrationMetrics,
    );
  }
}
