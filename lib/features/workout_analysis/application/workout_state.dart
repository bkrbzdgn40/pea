import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import 'engine_kind.dart';

class WorkoutCalibrationMetrics {
  const WorkoutCalibrationMetrics({
    this.currentBackAngle = 0.0,
    this.formThreshold = 0.0,
    this.isRangeRepFrameValid = true,
    this.hasPrimaryAngle = false,
    this.hasFormMetric = false,
    this.rangeRepInvalidReason,
    this.currentBodyLineAngle,
    this.currentArmSupportAngle,
    this.currentLegExtensionAngle,
    this.hasBodyLineAngle = false,
    this.hasArmSupportAngle = false,
    this.hasLegExtensionAngle = false,
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
  final bool isRangeRepFrameValid;
  final bool hasPrimaryAngle;
  final bool hasFormMetric;
  final String? rangeRepInvalidReason;
  final double? currentBodyLineAngle;
  final double? currentArmSupportAngle;
  final double? currentLegExtensionAngle;
  final bool hasBodyLineAngle;
  final bool hasArmSupportAngle;
  final bool hasLegExtensionAngle;
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
  final EngineKind analysisKind;
  final int repCount;
  final bool isFormBad;
  final double currentAngle;
  final double lastRepScore;
  final double lastRepROM;
  final double currentHoldSeconds;
  final double bestHoldSeconds;
  final bool isHolding;
  final bool hadHoldFormBreak;
  final String feedbackMessage;
  final String currentPhase;
  final double cameraFps;
  final double analysisFps;
  final WorkoutCalibrationMetrics calibrationMetrics;

  WorkoutState({
    this.landmarks,
    this.analysisKind = EngineKind.rangeRep,
    this.repCount = 0,
    this.isFormBad = false,
    this.currentAngle = 0.0,
    this.lastRepScore = 0.0,
    this.lastRepROM = 0.0,
    this.currentHoldSeconds = 0.0,
    this.bestHoldSeconds = 0.0,
    this.isHolding = false,
    this.hadHoldFormBreak = false,
    this.feedbackMessage = 'Hazir misin?',
    this.currentPhase = 'NEUTRAL',
    this.cameraFps = 0.0,
    this.analysisFps = 0.0,
    this.calibrationMetrics = const WorkoutCalibrationMetrics(),
  });

  // Mevcut durumu secili alanlarla kopyalar.
  WorkoutState copyWith({
    List<PoseLandmark>? landmarks,
    EngineKind? analysisKind,
    int? repCount,
    bool? isFormBad,
    double? currentAngle,
    double? lastRepScore,
    double? lastRepROM,
    double? currentHoldSeconds,
    double? bestHoldSeconds,
    bool? isHolding,
    bool? hadHoldFormBreak,
    String? feedbackMessage,
    String? currentPhase,
    double? cameraFps,
    double? analysisFps,
    WorkoutCalibrationMetrics? calibrationMetrics,
  }) {
    return WorkoutState(
      landmarks: landmarks ?? this.landmarks,
      analysisKind: analysisKind ?? this.analysisKind,
      repCount: repCount ?? this.repCount,
      isFormBad: isFormBad ?? this.isFormBad,
      currentAngle: currentAngle ?? this.currentAngle,
      lastRepScore: lastRepScore ?? this.lastRepScore,
      lastRepROM: lastRepROM ?? this.lastRepROM,
      currentHoldSeconds: currentHoldSeconds ?? this.currentHoldSeconds,
      bestHoldSeconds: bestHoldSeconds ?? this.bestHoldSeconds,
      isHolding: isHolding ?? this.isHolding,
      hadHoldFormBreak: hadHoldFormBreak ?? this.hadHoldFormBreak,
      feedbackMessage: feedbackMessage ?? this.feedbackMessage,
      currentPhase: currentPhase ?? this.currentPhase,
      cameraFps: cameraFps ?? this.cameraFps,
      analysisFps: analysisFps ?? this.analysisFps,
      calibrationMetrics: calibrationMetrics ?? this.calibrationMetrics,
    );
  }
}
