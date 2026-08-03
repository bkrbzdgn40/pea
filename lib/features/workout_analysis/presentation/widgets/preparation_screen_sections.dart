import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/presentation/widgets/app_feedback_banner.dart';
import '../../../../app/presentation/widgets/app_icon_button.dart';
import '../../../../app/presentation/widgets/app_status_tone.dart';
import '../../../../app/presentation/widgets/app_surface_card.dart';
import '../../../../app/theme/app_design_tokens.dart';
import '../../../../app/theme/app_semantic_colors.dart';

class PreparationGuideAction extends StatelessWidget {
  const PreparationGuideAction({
    super.key,
    required this.compact,
    required this.onPressed,
  });

  final bool compact;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    if (compact) {
      return AppIconButton(
        key: const ValueKey<String>('preparation-guide-action'),
        tooltip: localizations.preparationGuide,
        onPressed: onPressed,
        icon: Icons.help_outline_rounded,
        variant: AppIconButtonVariant.filled,
      );
    }

    return TextButton.icon(
      key: const ValueKey<String>('preparation-guide-action'),
      onPressed: onPressed,
      icon: const Icon(Icons.help_outline_rounded, size: 20),
      label: Text(localizations.preparationGuide),
    );
  }
}

class PreparationLandscapeToolbar extends StatelessWidget {
  const PreparationLandscapeToolbar({
    super.key,
    required this.title,
    required this.onBack,
    required this.onGuide,
  });

  final String title;
  final VoidCallback onBack;
  final VoidCallback onGuide;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final colors = context.semanticColors;

    return AppSurfaceCard(
      key: const ValueKey<String>('preparation-landscape-toolbar'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xxs,
      ),
      variant: AppSurfaceVariant.muted,
      child: Row(
        children: [
          IconButton(
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const SizedBox(width: AppSpacing.xxs),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: colors.foreground,
                fontWeight: AppFontWeights.heavy,
              ),
            ),
          ),
          AppIconButton(
            key: const ValueKey<String>('preparation-guide-action'),
            tooltip: localizations.preparationGuide,
            onPressed: onGuide,
            icon: Icons.help_outline_rounded,
            variant: AppIconButtonVariant.filled,
          ),
        ],
      ),
    );
  }
}

class PreparationHeader extends StatelessWidget {
  const PreparationHeader({
    super.key,
    required this.exerciseName,
    required this.summary,
    required this.compact,
  });

  final String exerciseName;
  final String summary;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;

    return AppSurfaceCard(
      key: const ValueKey<String>('preparation-compact-header'),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? AppSpacing.sm : AppSpacing.md,
        vertical: compact ? AppSpacing.sm : 14,
      ),
      color: colors.analysisAccent.withValues(alpha: 0.08),
      borderColor: colors.analysisAccent.withValues(alpha: 0.28),
      child: Row(
        children: [
          Container(
            width: compact ? 42 : 48,
            height: compact ? 42 : 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.analysisAccent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppRadii.compact),
              border: Border.all(
                color: colors.analysisAccent.withValues(alpha: 0.24),
              ),
            ),
            child: Icon(
              Icons.center_focus_strong_rounded,
              color: colors.analysisAccent,
              size: compact ? 23 : 26,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  exerciseName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.foreground,
                    fontSize: compact ? 20 : 24,
                    height: 1.1,
                    fontWeight: AppFontWeights.heavy,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  summary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.analysisAccent,
                    fontSize: compact ? 13 : 15,
                    height: 1.25,
                    fontWeight: AppFontWeights.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PreparationNotices extends StatelessWidget {
  const PreparationNotices({
    super.key,
    required this.fallbackMessage,
    required this.hasConfigError,
    required this.onRetryConfig,
  });

  final String? fallbackMessage;
  final bool hasConfigError;
  final VoidCallback onRetryConfig;

  @override
  Widget build(BuildContext context) {
    if (fallbackMessage == null && !hasConfigError) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (fallbackMessage != null)
            PreparationMessageCard(message: fallbackMessage!),
          if (fallbackMessage != null && hasConfigError)
            const SizedBox(height: AppSpacing.xs),
          if (hasConfigError) PreparationConfigError(onRetry: onRetryConfig),
        ],
      ),
    );
  }
}

class PreparationCameraStage extends StatelessWidget {
  const PreparationCameraStage({
    super.key,
    required this.aspectRatio,
    required this.child,
  });

  final double aspectRatio;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        var width = constraints.maxWidth;
        var height = width / aspectRatio;
        if (height > constraints.maxHeight) {
          height = constraints.maxHeight;
          width = height * aspectRatio;
        }

        return Center(
          child: SizedBox(
            key: const ValueKey<String>('preparation-camera-stage'),
            width: width,
            height: height,
            child: child,
          ),
        );
      },
    );
  }
}

class PreparationMessageCard extends StatelessWidget {
  const PreparationMessageCard({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return AppFeedbackBanner(
      message: message,
      tone: AppStatusTone.caution,
      icon: Icons.info_outline_rounded,
      liveRegion: false,
    );
  }
}

class PreparationConfigError extends StatelessWidget {
  const PreparationConfigError({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return AppFeedbackBanner(
      title: localizations.preparationReadinessNeedsAdjustment,
      message: localizations.analysisConfigLoadFailed,
      tone: AppStatusTone.danger,
      actionLabel: localizations.retry,
      onAction: onRetry,
      icon: Icons.sync_problem_rounded,
    );
  }
}

CameraValue? safeCameraValue(CameraController controller) {
  try {
    return controller.value;
  } catch (_) {
    return null;
  }
}
