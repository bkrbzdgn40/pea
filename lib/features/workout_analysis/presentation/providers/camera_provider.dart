import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import 'settings_provider.dart';

final cameraProvider = FutureProvider.autoDispose<CameraController>((
  ref,
) async {
  final permissionStatus = await Permission.camera.status;
  if (!permissionStatus.isGranted) {
    throw CameraException(
      'cameraPermission',
      ref.read(appLocalizationsProvider).cameraPermissionAnalysisRequired,
    );
  }

  CameraController? controller;
  try {
    final settings = await ref.watch(settingsControllerProvider.future);
    final cameras = await availableCameras();

    if (cameras.isEmpty) {
      throw CameraException(
        'cameraUnavailable',
        'No camera is available on this device.',
      );
    }

    final selectedCamera = cameras.firstWhere(
      (camera) =>
          camera.lensDirection ==
          _cameraLensDirection(settings.cameraPreference),
      orElse: () => cameras.first,
    );

    final initializedController = CameraController(
      selectedCamera,
      _resolutionPreset(settings.cameraQuality),
      enableAudio: false,
      imageFormatGroup: _cameraImageFormatGroup,
    );
    controller = initializedController;

    await initializedController.initialize();

    ref.onDispose(() {
      initializedController.dispose();
    });

    return initializedController;
  } catch (error, stackTrace) {
    await controller?.dispose();
    debugPrint('Workout camera initialization failed: $error');
    debugPrintStack(stackTrace: stackTrace);
    Error.throwWithStackTrace(error, stackTrace);
  }
});

CameraLensDirection _cameraLensDirection(WorkoutCameraPreference preference) {
  return switch (preference) {
    WorkoutCameraPreference.front => CameraLensDirection.front,
    WorkoutCameraPreference.back => CameraLensDirection.back,
  };
}

ResolutionPreset _resolutionPreset(WorkoutCameraQuality quality) {
  return switch (quality) {
    WorkoutCameraQuality.low => ResolutionPreset.low,
    WorkoutCameraQuality.medium => ResolutionPreset.medium,
    WorkoutCameraQuality.high => ResolutionPreset.high,
  };
}

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
