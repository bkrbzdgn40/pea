import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../../../app/localization/app_localizations.dart';

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
      return IconButton(
        key: const ValueKey<String>('preparation-guide-action'),
        tooltip: localizations.preparationGuide,
        onPressed: onPressed,
        icon: const Icon(Icons.help_outline_rounded),
      );
    }

    return TextButton.icon(
      key: const ValueKey<String>('preparation-guide-action'),
      style: TextButton.styleFrom(foregroundColor: Colors.white),
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
    return Row(
      key: const ValueKey<String>('preparation-landscape-toolbar'),
      children: [
        IconButton(
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        IconButton(
          key: const ValueKey<String>('preparation-guide-action'),
          tooltip: localizations.preparationGuide,
          onPressed: onGuide,
          icon: const Icon(Icons.help_outline_rounded),
        ),
      ],
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
    return Column(
      key: const ValueKey<String>('preparation-compact-header'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          exerciseName,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white,
            fontSize: compact ? 20 : 24,
            height: 1.1,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          summary,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: const Color(0xFFB9F3E7),
            fontSize: compact ? 13 : 15,
            height: 1.25,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
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
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (fallbackMessage != null)
            PreparationMessageCard(message: fallbackMessage!),
          if (fallbackMessage != null && hasConfigError)
            const SizedBox(height: 10),
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
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 14,
          height: 1.35,
        ),
      ),
    );
  }
}

class PreparationConfigError extends StatelessWidget {
  const PreparationConfigError({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              AppLocalizations.of(context).analysisConfigLoadFailed,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: Text(AppLocalizations.of(context).retry),
          ),
        ],
      ),
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
