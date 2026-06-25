import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Ön kamerayı başlatıp controller döndürür.
final cameraProvider = FutureProvider.autoDispose<CameraController>((
  ref,
) async {
  final cameras = await availableCameras();

  final frontCamera = cameras.firstWhere(
    (camera) => camera.lensDirection == CameraLensDirection.front,
    orElse: () => cameras.first,
  );

  final controller = CameraController(
    frontCamera,
    // Cihazdaki gralloc/bellek hatalarını gidermek için çözünürlüğü düşürüyoruz
    ResolutionPreset.low, 
    enableAudio: false,
    imageFormatGroup: ImageFormatGroup.nv21, 
  );

  await controller.initialize();

  ref.onDispose(() {
    controller.dispose();
  });

  return controller;
});
