import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class ExerciseConfig {
  final String name;
  final PoseLandmarkType primaryJoint; // Açı merkezi (Örn: Diz)
  final PoseLandmarkType joint1; // Açıyı oluşturan nokta 1 (Örn: Kalça)
  final PoseLandmarkType joint2; // Açıyı oluşturan nokta 2 (Örn: Ayak Bileği)

  // Hareket eşikleri
  final double thresholdNeutral; // Ayakta duruş açısı (Örn: 160+)
  final double thresholdActive; // Hareketin başladığı açı (Örn: 150)
  final double
  thresholdPeak; // Tekrarın sayılması için gereken min/max açı (Örn: 90-)

  // Kalite kriterleri
  final double idealDescentSeconds; // İdeal iniş süresi
  final double idealAscentSeconds; // İdeal kalkış süresi
  final double formThreshold; // Form hatası açısı
  final double targetMinAngle;
  final double tempoPenaltyPerSecond;

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
    this.targetMinAngle = 70.0,
    this.tempoPenaltyPerSecond = 20.0,
  });

  factory ExerciseConfig.fromMap(Map<String, dynamic> map) {
    PoseLandmarkType readLandmark(String key) {
      final value = map[key];
      if (value is! String) {
        throw FormatException('ExerciseConfig.$key must be a String.');
      }

      try {
        return PoseLandmarkType.values.byName(value);
      } on ArgumentError {
        throw FormatException('Unsupported PoseLandmarkType for $key: $value');
      }
    }

    double readDouble(String key) {
      final value = map[key];
      if (value is num) {
        return value.toDouble();
      }
      if (value is String) {
        return double.parse(value);
      }

      throw FormatException('ExerciseConfig.$key must be a number.');
    }

    final name = map['name'];
    if (name is! String) {
      throw FormatException('ExerciseConfig.name must be a String.');
    }

    return ExerciseConfig(
      name: name,
      primaryJoint: readLandmark('primaryJoint'),
      joint1: readLandmark('joint1'),
      joint2: readLandmark('joint2'),
      thresholdNeutral: readDouble('thresholdNeutral'),
      thresholdActive: readDouble('thresholdActive'),
      thresholdPeak: readDouble('thresholdPeak'),
      idealDescentSeconds: readDouble('idealDescentSeconds'),
      idealAscentSeconds: readDouble('idealAscentSeconds'),
      formThreshold: readDouble('formThreshold'),
      targetMinAngle: readDouble('targetMinAngle'),
      tempoPenaltyPerSecond: readDouble('tempoPenaltyPerSecond'),
    );
  }
}
