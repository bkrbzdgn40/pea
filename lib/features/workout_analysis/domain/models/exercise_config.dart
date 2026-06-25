import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class ExerciseConfig {
  final String name;
  final PoseLandmarkType primaryJoint; // Açı merkezi (Örn: Diz)
  final PoseLandmarkType joint1;       // Açıyı oluşturan nokta 1 (Örn: Kalça)
  final PoseLandmarkType joint2;       // Açıyı oluşturan nokta 2 (Örn: Ayak Bileği)
  
  // Hareket eşikleri
  final double thresholdNeutral;      // Ayakta duruş açısı (Örn: 160+)
  final double thresholdActive;       // Hareketin başladığı açı (Örn: 150)
  final double thresholdPeak;         // Tekrarın sayılması için gereken min/max açı (Örn: 90-)
  
  // Kalite kriterleri
  final double idealDescentSeconds;   // İdeal iniş süresi
  final double idealAscentSeconds;    // İdeal kalkış süresi
  final double formThreshold;         // Form hatası açısı

  ExerciseConfig({
    required this.name,
    required this.primaryJoint,
    required this.joint1,
    required this.joint2,
    required this.thresholdNeutral,
    required this.thresholdActive,
    required this.thresholdPeak,
    this.idealDescentSeconds = 2.0,
    this.idealAscentSeconds = 1.0,
    this.formThreshold = 45.0,
  });

  // İleride JSON'dan yüklemek için
  // Squat için varsayılan eşikleri kurar.
  factory ExerciseConfig.squat() => ExerciseConfig(
        name: "Squat",
        primaryJoint: PoseLandmarkType.leftKnee,
        joint1: PoseLandmarkType.leftHip,
        joint2: PoseLandmarkType.leftAnkle,
        thresholdNeutral: 160.0,
        thresholdActive: 150.0,
        thresholdPeak: 95.0,
        idealDescentSeconds: 1.5,
        idealAscentSeconds: 1.0,
      );
}
