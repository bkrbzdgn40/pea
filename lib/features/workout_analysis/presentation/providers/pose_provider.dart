import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

/// Yapay zeka modelini başlatan ve yöneten Provider
// Pose detector örneğini üretir.
final poseDetectorProvider = Provider.autoDispose<PoseDetector>((ref) {
  // Modeli canlı akış (stream) modunda ve temel doğruluk (base) seviyesinde başlatıyoruz
  final options = PoseDetectorOptions(
    model: PoseDetectionModel.base,
    mode: PoseDetectionMode.stream,
  );

  final detector = PoseDetector(options: options);

  // Ekran kapatıldığında veya işlem bittiğinde modeli RAM'den temizle
  ref.onDispose(() {
    detector.close();
  });

  return detector;
});
