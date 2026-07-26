import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/app_localizations.dart';
import '../mappers/setup_readiness_ui_mapper.dart';
import '../models/setup_readiness_view_data.dart';
import '../providers/preparation_camera_controller.dart';
import '../providers/preparation_readiness_controller.dart';
import 'pose_painter.dart';

class PreparationCameraSurface extends StatelessWidget {
  const PreparationCameraSurface({
    required this.cameraState,
    required this.isRecovering,
    required this.countdownValue,
    required this.onControllerReady,
    required this.onRetry,
    required this.onCheckPermission,
    super.key,
  });

  final AsyncValue<CameraController> cameraState;
  final bool isRecovering;
  final int? countdownValue;
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
                  _PreparationReadinessOverlay(
                    request: (
                      imageWidth: imageSize.width,
                      imageHeight: imageSize.height,
                      mirrorHorizontally: isMirrored,
                    ),
                  ),
                  if (countdownValue != null)
                    _PreparationCountdownOverlay(value: countdownValue!),
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

class _PreparationCountdownOverlay extends StatelessWidget {
  const _PreparationCountdownOverlay({required this.value});

  final int value;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return Positioned.fill(
      child: IgnorePointer(
        child: ColoredBox(
          color: Colors.black.withValues(alpha: 0.32),
          child: Center(
            child: Semantics(
              liveRegion: true,
              label: localizations.preparationCountdownSemantics(value),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                transitionBuilder: (child, animation) {
                  return ScaleTransition(
                    scale: CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutBack,
                    ),
                    child: FadeTransition(opacity: animation, child: child),
                  );
                },
                child: Container(
                  key: ValueKey<String>('preparation-countdown-$value'),
                  width: 132,
                  height: 132,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.78),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.greenAccent, width: 4),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.greenAccent.withValues(alpha: 0.28),
                        blurRadius: 24,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: Text(
                    value.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 68,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PreparationReadinessOverlay extends ConsumerWidget {
  const _PreparationReadinessOverlay({required this.request});

  final SetupReadinessRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final readiness = mapSetupReadinessToViewData(
      localizations: AppLocalizations.of(context),
      readinessSnapshot: ref.watch(preparationReadinessStateProvider(request)),
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        _PreparationSafeZoneOverlay(readiness: readiness),
        _PreparationReadinessBanner(readiness: readiness),
      ],
    );
  }
}

class _PreparationSafeZoneOverlay extends StatelessWidget {
  const _PreparationSafeZoneOverlay({required this.readiness});

  final SetupReadinessViewData readiness;

  @override
  Widget build(BuildContext context) {
    final color = _readinessColor(readiness.visualState);
    return Positioned.fill(
      child: IgnorePointer(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: AnimatedContainer(
            key: const ValueKey<String>('preparation-safe-zone'),
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: color.withValues(alpha: 0.82),
                width: readiness.isReady ? 3 : 2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PreparationReadinessBanner extends StatelessWidget {
  const _PreparationReadinessBanner({required this.readiness});

  final SetupReadinessViewData readiness;

  @override
  Widget build(BuildContext context) {
    final color = _readinessColor(readiness.visualState);
    return Positioned(
      left: 12,
      right: 12,
      bottom: 12,
      child: Semantics(
        liveRegion: true,
        label: '${readiness.statusLabel}: ${readiness.message}',
        child: AnimatedContainer(
          key: const ValueKey<String>('preparation-readiness-banner'),
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.76),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.7)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                _readinessIcon(readiness.visualState),
                color: color,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      readiness.statusLabel,
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      readiness.message,
                      key: const ValueKey<String>(
                        'preparation-readiness-message',
                      ),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Color _readinessColor(SetupReadinessVisualState state) {
  return switch (state) {
    SetupReadinessVisualState.checking => Colors.amberAccent,
    SetupReadinessVisualState.needsAdjustment => Colors.orangeAccent,
    SetupReadinessVisualState.ready => Colors.greenAccent,
  };
}

IconData _readinessIcon(SetupReadinessVisualState state) {
  return switch (state) {
    SetupReadinessVisualState.checking => Icons.manage_search_rounded,
    SetupReadinessVisualState.needsAdjustment => Icons.tune_rounded,
    SetupReadinessVisualState.ready => Icons.check_circle_rounded,
  };
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
