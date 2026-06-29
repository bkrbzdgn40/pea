import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

// Ön kamerayı başlatıp controller döndürür.
final cameraProvider = FutureProvider.autoDispose<CameraController>((
  ref,
) async {
  final permissionStatus = await Permission.camera.status;
  if (!permissionStatus.isGranted) {
    throw CameraException(
      'cameraPermission',
      'Kamera izni olmadan analiz başlatılamaz.',
    );
  }

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
    imageFormatGroup: _cameraImageFormatGroup,
  );

  await controller.initialize();

  ref.onDispose(() {
    controller.dispose();
  });

  return controller;
});

ImageFormatGroup get _cameraImageFormatGroup {
  switch (defaultTargetPlatform) {
    case TargetPlatform.iOS:
      return ImageFormatGroup.bgra8888;
    case TargetPlatform.android:
      return ImageFormatGroup.nv21;
    default:
      return ImageFormatGroup.nv21;
  }
}
