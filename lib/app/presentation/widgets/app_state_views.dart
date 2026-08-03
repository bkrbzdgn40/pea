import 'package:flutter/material.dart';

import '../../theme/app_design_tokens.dart';
import '../../theme/app_semantic_colors.dart';
import 'app_button.dart';
import 'app_surface_card.dart';

class AppLoadingView extends StatelessWidget {
  const AppLoadingView({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;

    return Center(
      child: Semantics(
        container: true,
        liveRegion: true,
        label: message,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: colors.accent),
            if (message != null) ...[
              const SizedBox(height: AppSpacing.lg),
              Text(
                message!,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: colors.foreground),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class AppErrorView extends StatelessWidget {
  const AppErrorView({
    super.key,
    required this.message,
    this.title,
    this.icon,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? title;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;

    return Center(
      child: AppSurfaceCard(
        variant: AppSurfaceVariant.strong,
        padding: AppSpacing.headerSurfacePadding,
        radius: AppRadii.surface,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, color: colors.danger, size: 40),
              SizedBox(height: title != null ? AppSpacing.md : AppSpacing.xs),
            ],
            if (title != null) ...[
              Text(
                title!,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: colors.foreground,
                  fontWeight: AppFontWeights.heavy,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xs),
            ],
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colors.foregroundMuted,
                height: 1.35,
              ),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.lg),
              AppButton(label: actionLabel!, onPressed: onAction),
            ],
          ],
        ),
      ),
    );
  }
}

class AppEmptyView extends StatelessWidget {
  const AppEmptyView({
    super.key,
    required this.message,
    this.title,
    this.icon = Icons.inbox_outlined,
    this.centered = false,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? title;
  final IconData icon;
  final bool centered;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final content = centered ? _buildCentered(context) : _buildInline(context);
    if (centered) {
      return Center(child: content);
    }
    return content;
  }

  Widget _buildCentered(BuildContext context) {
    final colors = context.semanticColors;

    return AppSurfaceCard(
      variant: AppSurfaceVariant.muted,
      padding: const EdgeInsets.all(AppSpacing.xl),
      radius: AppRadii.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: colors.accent, size: 42),
          if (title != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              title!,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: colors.foreground,
                fontWeight: AppFontWeights.heavy,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: AppSpacing.xs),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colors.foregroundMuted,
              height: 1.35,
            ),
            textAlign: TextAlign.center,
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: AppSpacing.lg),
            AppButton(label: actionLabel!, onPressed: onAction),
          ],
        ],
      ),
    );
  }

  Widget _buildInline(BuildContext context) {
    final colors = context.semanticColors;

    return AppSurfaceCard(
      variant: AppSurfaceVariant.muted,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: colors.accent, size: 24),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (title != null) ...[
                      Text(
                        title!,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: colors.foreground,
                              fontWeight: AppFontWeights.heavy,
                            ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                    ],
                    Text(
                      message,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.foregroundMuted,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: AppSpacing.xs),
            AppButton(
              label: actionLabel!,
              onPressed: onAction,
              variant: AppButtonVariant.ghost,
            ),
          ],
        ],
      ),
    );
  }
}
