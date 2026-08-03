import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/presentation/widgets/app_button.dart';
import '../../../../app/presentation/widgets/app_status_chip.dart';
import '../../../../app/theme/app_design_tokens.dart';
import '../../../../app/theme/app_motion.dart';
import '../../../../app/theme/app_semantic_colors.dart';
import '../errors/workout_camera_error_presentation.dart';
import '../mappers/setup_readiness_ui_mapper.dart';
import '../models/preparation_pose_guide.dart';
import '../models/preparation_camera_geometry.dart';
import '../models/setup_readiness_view_data.dart';
import '../providers/preparation_camera_controller.dart';
import '../providers/preparation_readiness_controller.dart';
import 'preparation_start_pose_reference.dart';
import 'preparation_visual_style.dart';
import 'pose_painter.dart';

class PreparationCameraSurface extends StatelessWidget {
  const PreparationCameraSurface({
    required this.cameraState,
    required this.geometry,
    required this.viewportOrientation,
    required this.isRecovering,
    required this.startPoseTemplate,
    required this.startPoseGuideTitle,
    required this.countdownValue,
    required this.onControllerReady,
    required this.onRetry,
    required this.onCheckPermission,
    super.key,
  });

  final AsyncValue<CameraController> cameraState;
  final PreparationCameraGeometry? geometry;
  final Orientation viewportOrientation;
  final bool isRecovering;
  final PreparationPoseTemplate startPoseTemplate;
  final String startPoseGuideTitle;
  final int? countdownValue;
  final ValueChanged<CameraController> onControllerReady;
  final VoidCallback onRetry;
  final VoidCallback onCheckPermission;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final colors = context.semanticColors;

    return AspectRatio(
      key: const ValueKey<String>('preparation-camera-aspect-ratio'),
      aspectRatio:
          geometry?.aspectRatio ??
          (viewportOrientation == Orientation.landscape ? 4 / 3 : 3 / 4),
      child: DecoratedBox(
        key: const ValueKey<String>('preparation-camera-frame'),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              colors.surfaceStrong,
              Colors.black,
              colors.surfaceMuted,
            ],
          ),
          borderRadius: BorderRadius.circular(AppRadii.large),
          border: Border.all(
            color: colors.analysisAccent.withValues(alpha: 0.42),
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: colors.analysisAccent.withValues(alpha: 0.14),
              blurRadius: 30,
              spreadRadius: 1,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.large),
          child: cameraState.when(
            skipLoadingOnRefresh: false,
            skipLoadingOnReload: false,
            data: (controller) {
              if (isRecovering || cameraState.isLoading) {
                return const _PreparationCameraLoading();
              }

              final value = _safeCameraValue(controller);
              if (value == null ||
                  !value.isInitialized ||
                  value.previewSize == null ||
                  geometry == null) {
                return const _PreparationCameraLoading();
              }

              onControllerReady(controller);
              final imageSize = geometry!.imageSize;
              final isMirrored =
                  controller.description.lensDirection ==
                  CameraLensDirection.front;

              return Stack(
                key: const ValueKey<String>('preparation-camera-preview'),
                fit: StackFit.expand,
                children: [
                  CameraPreview(controller),
                  const _PreparationCameraVignette(),
                  PreparationStartPoseReference(
                    template: startPoseTemplate,
                    title: startPoseGuideTitle,
                  ),
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
              final failure = presentWorkoutCameraError(
                error: error,
                localizations: localizations,
              );
              return _PreparationCameraError(
                message: failure.message,
                actionLabel: failure.actionLabel,
                onPressed: failure.requiresPermissionAction
                    ? onCheckPermission
                    : onRetry,
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

    return RepaintBoundary(
      child: CustomPaint(
        key: const ValueKey<String>('preparation-pose-overlay'),
        painter: PosePainter(
          landmarks,
          imageSize,
          isFormBad: false,
          isMirrored: isMirrored,
        ),
      ),
    );
  }
}

class _PreparationCameraVignette extends StatelessWidget {
  const _PreparationCameraVignette();

  @override
  Widget build(BuildContext context) {
    return const Positioned.fill(
      child: IgnorePointer(
        child: DecoratedBox(
          key: ValueKey<String>('preparation-camera-vignette'),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                Color(0x66000000),
                Color(0x00000000),
                Color(0x12000000),
                Color(0xB8000000),
              ],
              stops: <double>[0, 0.24, 0.62, 1],
            ),
          ),
        ),
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
    final colors = context.semanticColors;

    return Positioned.fill(
      child: IgnorePointer(
        child: ColoredBox(
          color: Colors.black.withValues(alpha: 0.52),
          child: Center(
            child: Semantics(
              liveRegion: true,
              label: localizations.preparationCountdownSemantics(value),
              child: AnimatedSwitcher(
                duration: AppMotion.resolveDuration(
                  context,
                  AppMotionDurations.fast,
                ),
                transitionBuilder: (child, animation) {
                  return ScaleTransition(
                    scale: CurvedAnimation(
                      parent: animation,
                      curve: AppMotion.resolveCurve(
                        context,
                        Curves.easeOutBack,
                      ),
                    ),
                    child: FadeTransition(opacity: animation, child: child),
                  );
                },
                child: Column(
                  key: ValueKey<String>('preparation-countdown-$value'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 142,
                      height: 142,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.82),
                        shape: BoxShape.circle,
                        border: Border.all(color: colors.success, width: 4),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: colors.success.withValues(alpha: 0.34),
                            blurRadius: 34,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox.square(
                            dimension: 118,
                            child: CircularProgressIndicator(
                              value: (4 - value).clamp(0, 3) / 3,
                              strokeWidth: 3,
                              color: colors.success,
                              backgroundColor: colors.success.withValues(
                                alpha: 0.16,
                              ),
                            ),
                          ),
                          Text(
                            value.toString(),
                            style: TextStyle(
                              color: colors.foreground,
                              fontSize: 68,
                              fontWeight: AppFontWeights.heavy,
                              height: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Container(
                      constraints: const BoxConstraints(maxWidth: 300),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.68),
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                        border: Border.all(
                          color: colors.success.withValues(alpha: 0.34),
                        ),
                      ),
                      child: Text(
                        localizations.preparationCountdownMessage,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.foreground,
                          fontWeight: AppFontWeights.semibold,
                        ),
                      ),
                    ),
                  ],
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
        Positioned(
          top: AppSpacing.sm,
          right: AppSpacing.sm,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 190),
            child: AppStatusChip(
              key: const ValueKey<String>(
                'preparation-camera-readiness-status',
              ),
              label: readiness.statusLabel,
              tone: PreparationVisualStyle.readinessTone(readiness.visualState),
              icon: PreparationVisualStyle.readinessIcon(readiness.visualState),
            ),
          ),
        ),
      ],
    );
  }
}

class _PreparationSafeZoneOverlay extends StatelessWidget {
  const _PreparationSafeZoneOverlay({required this.readiness});

  final SetupReadinessViewData readiness;

  @override
  Widget build(BuildContext context) {
    final color = PreparationVisualStyle.readinessColor(
      context,
      readiness.visualState,
    ).withValues(alpha: 0.92);

    return Positioned.fill(
      child: IgnorePointer(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: TweenAnimationBuilder<Color?>(
            tween: ColorTween(end: color),
            duration: AppMotion.resolveDuration(
              context,
              AppMotionDurations.fast,
            ),
            builder: (context, animatedColor, _) {
              return RepaintBoundary(
                child: CustomPaint(
                  key: const ValueKey<String>('preparation-safe-zone'),
                  painter: _PreparationSafeZonePainter(
                    color: animatedColor ?? color,
                    strokeWidth: readiness.isReady ? 3 : 2,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _PreparationSafeZonePainter extends CustomPainter {
  const _PreparationSafeZonePainter({
    required this.color,
    required this.strokeWidth,
  });

  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final guideRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final guidePaint = Paint()
      ..color = color.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRRect(
      RRect.fromRectAndRadius(guideRect, const Radius.circular(18)),
      guidePaint,
    );

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final cornerLength = (size.shortestSide * 0.12)
        .clamp(20.0, 36.0)
        .toDouble();
    final path = Path()
      ..moveTo(0, cornerLength)
      ..lineTo(0, 0)
      ..lineTo(cornerLength, 0)
      ..moveTo(size.width - cornerLength, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, cornerLength)
      ..moveTo(size.width, size.height - cornerLength)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width - cornerLength, size.height)
      ..moveTo(cornerLength, size.height)
      ..lineTo(0, size.height)
      ..lineTo(0, size.height - cornerLength);
    canvas.drawPath(path, paint);

    final center = Offset(size.width / 2, size.height / 2);
    final crosshairPaint = Paint()
      ..color = color.withValues(alpha: 0.36)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawLine(
        Offset(center.dx - 8, center.dy),
        Offset(center.dx + 8, center.dy),
        crosshairPaint,
      )
      ..drawLine(
        Offset(center.dx, center.dy - 8),
        Offset(center.dx, center.dy + 8),
        crosshairPaint,
      );
  }

  @override
  bool shouldRepaint(covariant _PreparationSafeZonePainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
  }
}

class _PreparationCameraLoading extends StatelessWidget {
  const _PreparationCameraLoading();

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;

    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final compact = constraints.maxHeight < 260 || textScale > 1.3;
        final outerPadding = compact ? AppSpacing.sm : AppSpacing.lg;
        final cardPadding = compact ? AppSpacing.md : AppSpacing.lg;

        return SingleChildScrollView(
          key: const ValueKey<String>('preparation-camera-loading'),
          padding: EdgeInsets.all(outerPadding),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: (constraints.maxHeight - (outerPadding * 2)).clamp(
                0.0,
                double.infinity,
              ),
            ),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 300),
                padding: EdgeInsets.all(cardPadding),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.68),
                  borderRadius: BorderRadius.circular(AppRadii.surface),
                  border: Border.all(color: colors.outline),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: compact ? 28 : 36,
                      height: compact ? 28 : 36,
                      child: CircularProgressIndicator(
                        strokeWidth: compact ? 2.5 : 3,
                        color: colors.analysisAccent,
                      ),
                    ),
                    SizedBox(height: compact ? AppSpacing.xs : AppSpacing.sm),
                    Text(
                      AppLocalizations.of(context).preparationCameraLoading,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.foreground,
                        fontWeight: AppFontWeights.semibold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
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
    final colors = context.semanticColors;

    return Center(
      key: const ValueKey<String>('preparation-camera-error'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 340),
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(AppRadii.surface),
            border: Border.all(color: colors.danger.withValues(alpha: 0.46)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.danger.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.photo_camera_outlined,
                  color: colors.danger,
                  size: 28,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.foreground,
                  height: 1.35,
                  fontWeight: AppFontWeights.semibold,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: actionLabel,
                onPressed: onPressed,
                variant: AppButtonVariant.outline,
                icon: Icons.refresh_rounded,
              ),
            ],
          ),
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
