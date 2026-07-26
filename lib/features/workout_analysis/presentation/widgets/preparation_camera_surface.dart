import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/app_localizations.dart';
import '../providers/preparation_camera_controller.dart';
import 'pose_painter.dart';

class PreparationCameraSurface extends StatelessWidget {
  const PreparationCameraSurface({
    required this.cameraState,
    required this.isRecovering,
    required this.onControllerReady,
    required this.onRetry,
    required this.onCheckPermission,
    super.key,
  });

  final AsyncValue<CameraController> cameraState;
  final bool isRecovering;
  final ValueChanged<CameraController> onControllerReady;
  final VoidCallback onRetry;
  final VoidCallback onCheckPermission;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return AspectRatio(
      aspectRatio: 3 / 4,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF101010),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white12),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: cameraState.when(
            skipLoadingOnRefresh: false,
            skipLoadingOnReload: false,
            data: (controller) {
              if (isRecovering || cameraState.isLoading) {
                return const _PreparationCameraLoading();
              }

              final value = _safeCameraValue(controller);
              final previewSize = value?.previewSize;
              if (value == null ||
                  !value.isInitialized ||
                  previewSize == null) {
                return const _PreparationCameraLoading();
              }

              onControllerReady(controller);
              final imageSize = Size(previewSize.height, previewSize.width);
              final isMirrored =
                  controller.description.lensDirection ==
                  CameraLensDirection.front;

              return Stack(
                key: const ValueKey<String>('preparation-camera-preview'),
                fit: StackFit.expand,
                children: [
                  CameraPreview(controller),
                  _PreparationPoseOverlay(
                    imageSize: imageSize,
                    isMirrored: isMirrored,
                  ),
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.68),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        localizations.preparationCameraPreviewHint,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          height: 1.3,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
            loading: () => const _PreparationCameraLoading(),
            error: (error, _) {
              final isPermissionError =
                  error is CameraException && error.code == 'cameraPermission';
              return _PreparationCameraError(
                message: isPermissionError
                    ? localizations.cameraPermissionFallbackBody
                    : localizations.cameraOpenFailed(error),
                actionLabel: isPermissionError
                    ? localizations.checkPermission
                    : localizations.retry,
                onPressed: isPermissionError ? onCheckPermission : onRetry,
              );
            },
          ),
        ),
      ),
    );
  }
}

class _PreparationPoseOverlay extends ConsumerWidget {
  const _PreparationPoseOverlay({
    required this.imageSize,
    required this.isMirrored,
  });

  final Size imageSize;
  final bool isMirrored;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final landmarks = ref.watch(
      preparationCameraControllerProvider.select((state) => state.landmarks),
    );
    if (landmarks.isEmpty) {
      return const SizedBox.shrink();
    }

    return CustomPaint(
      key: const ValueKey<String>('preparation-pose-overlay'),
      painter: PosePainter(
        landmarks,
        imageSize,
        isFormBad: false,
        isMirrored: isMirrored,
      ),
    );
  }
}

class _PreparationCameraLoading extends StatelessWidget {
  const _PreparationCameraLoading();

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const ValueKey<String>('preparation-camera-loading'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: Colors.greenAccent),
          const SizedBox(height: 14),
          Text(
            AppLocalizations.of(context).preparationCameraLoading,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _PreparationCameraError extends StatelessWidget {
  const _PreparationCameraError({
    required this.message,
    required this.actionLabel,
    required this.onPressed,
  });

  final String message;
  final String actionLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const ValueKey<String>('preparation-camera-error'),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.photo_camera_outlined,
              color: Colors.greenAccent,
              size: 40,
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 18),
            OutlinedButton(onPressed: onPressed, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}

CameraValue? _safeCameraValue(CameraController controller) {
  try {
    return controller.value;
  } catch (_) {
    return null;
  }
}
